class Loan::PostInstallment
  Result = Struct.new(:success?, :transfer, :interest_entry, :installment, :error, keyword_init: true)

  def initialize(family:, account_id:, source_account_id:, installment_no: nil, date: nil, late_fee: nil)
    @family = family
    @account = family.accounts.find(account_id)
    @source = family.accounts.assets.find(source_account_id)
    @date = parse_date(date) || Date.current
    @installment_no = installment_no
    @late_fee = late_fee.to_d if late_fee
  end
  def call!
    raise ArgumentError, "Account is not Loan" unless @account.accountable_type == "Loan"

    if @installment_no.blank?
      last_posted = LoanInstallment.for_account(@account.id).order(:installment_no).where(status: "posted").last
      if last_posted && last_posted.transfer_id.present? && LoanInstallment.for_account(@account.id).planned.none?
        return already_posted_result(last_posted)
      end
    end

    installment = find_installment!
    return already_posted_result(installment) if installment.status == "posted"
    transfer = nil
    interest_entry = nil
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    if defined?(Sentry)
      loan = @account.accountable
      Sentry.add_breadcrumb(Sentry::Breadcrumb.new(category: "loan.installment", message: "Posting installment", data: { loan_id: loan.id, installment_no: (@installment_no || "next"), idempotent: false })) rescue nil
      begin
        Sentry.configure_scope do |scope|
          scope.set_tags(loan_subtype: @account.subtype, feature_extra_payment: !!(Rails.application.config.features.dig(:loans, :extra_payment) rescue nil))
          scope.set_context("loan", { id: loan.id, account_id: @account.id, institution_type: loan.institution_type })
        end
      rescue NoMethodError; end
    end
    already_locked_posted = false
    ActiveRecord::Base.transaction do
      installment.lock!
      if installment.status == "posted"
        already_locked_posted = true
        raise ActiveRecord::Rollback
      end

      principal = installment.principal_amount.to_d
      interest = installment.interest_amount.to_d

      # 1) Principal: transfer from cash -> loan (skipped if no principal due)
      transfer = if principal.positive?
        ::Transfer::Creator.new(
          family: @family,
          source_account_id: @source.id,
          destination_account_id: @account.id,
          date: @date,
          amount: principal
        ).create
      end

      # 2) Interest: expense from cash only, categorized
      if interest.positive?
        interest_money = Money.new(interest, @account.currency)
        converted_interest = interest_money.exchange_to(
          @source.currency,
          date: @date,
          fallback_rate: 1.0
        )
        interest_entry = @source.entries.create!(
          date: @date,
          name: interest_name,
          amount: converted_interest.amount,
          currency: @source.currency,
          entryable: Transaction.new(kind: interest_kind)
        )
        # Resolve category by key, fallback to name
        sys_key = @account.accountable.sharia_compliant? ? "system:islamic_profit_expense" : "system:interest_expense"
        category = CategoryResolver.ensure_system_category(@family, sys_key)
        interest_entry.entryable.set_category!(category)
      end

      # 3) Optional late fee as expense
      if @late_fee && @late_fee.positive?
        late_entry = @source.entries.create!(
          date: @date,
          name: "Loan late fee — #{@account.name}",
          amount: @late_fee,
          currency: @source.currency,
          entryable: Transaction.new(kind: "loan_payment")
        )
        late_cat = CategoryResolver.ensure_system_category(@family, "system:late_fee_expense")
        late_entry.entryable.set_category!(late_cat)
      end

      installment.update!(status: "posted", posted_on: @date, transfer_id: transfer&.id)
      ActiveSupport::Notifications.instrument("sure.loan.installment.posted", loan_id: @account.accountable_id, installment_no: installment.installment_no, idempotent: false) rescue nil

      @account.sync_later
      @source.sync_later
    end
    return already_posted_result(installment) if already_locked_posted
    ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round(1)
    if defined?(Sentry)
      begin
        Sentry.with_child_span(op: "loan.installment.post", description: "Loan #{@account.accountable_id}") do |span|
          span.set_data(:loan_id, @account.accountable_id) rescue nil
          span.set_data(:installment_no, installment.installment_no) rescue nil
          span.set_data(:transfer_id, transfer&.id) rescue nil
        end
        tx = Sentry.get_current_scope.get_transaction
        record_measurement(tx, "loan.installment.total_amount", (installment.total_amount || 0).to_f, "none")
        record_measurement(tx, "loan.installment.ms", ms, "millisecond")
      rescue NoMethodError; end
    end
    Rails.logger.info({ at: "Loan::PostInstallment", account_id: @account.id, installment_no: installment.installment_no, transfer_id: transfer&.id, ms: ms }.to_json)
    Result.new(success?: true, transfer: transfer, interest_entry: interest_entry, installment: installment)
  rescue => e
    Rails.logger.error({ at: "Loan::PostInstallment.error", account_id: @account.id, installment_no: @installment_no, error: e.message }.to_json)
    # Handle unique index race gracefully
    if e.is_a?(ActiveRecord::RecordNotUnique)
      inst = LoanInstallment.for_account(@account.id).find_by(installment_no: @installment_no)
      if inst&.status == "posted" && inst.transfer_id.present?
        ActiveSupport::Notifications.instrument("sure.loan.installment.posted", loan_id: @account.accountable_id, installment_no: inst.installment_no, idempotent: true) rescue nil
        return already_posted_result(inst)
      end
    end
    Result.new(success?: false, error: e.message)
  end

  private
    def find_installment!
      if @installment_no.present?
        # Allow idempotent behavior by returning posted rows too
        LoanInstallment.for_account(@account.id).order(:installment_no).find_by!(installment_no: @installment_no)
      else
        LoanInstallment.for_account(@account.id).planned.order(:installment_no).first || raise(ActiveRecord::RecordNotFound, "No planned installments available")
      end
    end

    def interest_kind
      @account.accountable.sharia_compliant? ? "margin_payment" : "loan_payment"
    end

    def interest_name
      base = @account.accountable.sharia_compliant? ? "Profit portion of installment" : "Interest portion of installment"
      "#{base} — #{@account.name}"
    end

    def parse_date(val)
      return val if val.is_a?(Date)
      Date.parse(val.to_s) rescue nil
    end

    def already_posted_result(installment)
      Result.new(success?: true, transfer: (Transfer.find_by(id: installment.transfer_id) if installment.transfer_id), interest_entry: nil, installment: installment)
    end

    def record_measurement(tx, name, value, unit)
      return unless tx
      return unless tx.respond_to?(:set_measurement)

      method = tx.method(:set_measurement) rescue nil

      if method && method.arity != 0
        method.call(name, value, unit)
      else
        handler = (tx.set_measurement rescue nil)
        handler.call(name, value, unit) if handler.respond_to?(:call)
      end
    rescue StandardError
      nil
    end
end
