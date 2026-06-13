class Loan::ApplyExtraPayment
  Result = Struct.new(:success?, :installments, :error, keyword_init: true)

  def initialize(account:, amount:, date: Date.current, allocation_mode: "reduce_term")
    @account = account
    @amount = amount.to_d
    @date = date.is_a?(Date) ? date : Date.parse(date.to_s)
    @allocation_mode = %w[reduce_term reduce_installment].include?(allocation_mode) ? allocation_mode : "reduce_term"
  end

  def call!
    raise ArgumentError, "Account must be Loan" unless @account.accountable_type == "Loan"
    raise ArgumentError, "Amount must be positive" unless @amount.positive?

    loan = @account.accountable

    pending = @account.loan_installments.pending.order(:installment_no)
    pending_principal_total = pending.sum(:principal_amount).to_d

    ledger_remaining = Loan::RemainingPrincipalCalculator.new(@account).remaining_principal
    base_principal = ledger_remaining.positive? ? ledger_remaining : pending_principal_total
    remaining_principal = [ base_principal - @amount, 0.to_d ].max

    remaining_no = pending.count
    tenor_months = if @allocation_mode == "reduce_installment"
      [ remaining_no, 1 ].max
    else
      [ remaining_no, 1 ].max
    end

    if remaining_principal.positive?
      case @allocation_mode
      when "reduce_term"
        if pending_principal_total.positive?
          ratio = remaining_principal / pending_principal_total
          tenor_months = [ (remaining_no * ratio).ceil, 1 ].max
        end
      when "reduce_installment"
        tenor_months = [ (remaining_principal / average_principal_per_period(pending_principal_total, remaining_no)).ceil, 1 ].max
      end
    else
      tenor_months = 1
    end

    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    rows = Loan::ScheduleGenerator.new(
      principal_amount: remaining_principal,
      rate_or_profit: loan.interest_free? ? 0.to_d : Loan.normalize_rate(loan.rate_or_profit || loan.interest_rate || loan.margin_rate || 0),
      tenor_months: tenor_months,
      payment_frequency: loan.payment_frequency || "MONTHLY",
      schedule_method: loan.schedule_method || "ANNUITY",
      start_date: @date,
      balloon_amount: loan.balloon_amount || 0,
      loan_id: @account.accountable_id
    ).generate

    created = []
    ActiveRecord::Base.transaction do
      # Remove only future planned rows (>= today or > last posted)
      last_posted_no = @account.loan_installments.where(status: "posted").maximum(:installment_no) || 0
      @account.loan_installments
              .where(status: "planned")
              .where("due_date >= ? OR installment_no > ?", Date.current, last_posted_no)
              .delete_all

      rows.each_with_index do |row, idx|
        created << LoanInstallment.create!(
          account_id: @account.id,
          installment_no: last_posted_no + idx + 1,
          due_date: row.due_date,
          status: "planned",
          principal_amount: row.principal,
          interest_amount: row.interest,
          total_amount: row.total
        )
      end
    end

    ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round(1)
    if defined?(Sentry)
      begin
        Sentry.add_breadcrumb(Sentry::Breadcrumb.new(category: "loan.installment", message: "Applying extra payment", data: { loan_id: @account.accountable_id, amount: @amount.to_f, mode: @allocation_mode }))
        Sentry.configure_scope do |scope|
          scope.set_tags(feature_extra_payment: !!(Rails.application.config.features.dig(:loans, :extra_payment) rescue nil))
          scope.set_context("loan", { id: @account.accountable_id, account_id: @account.id, mode: @allocation_mode })
        end
        Sentry.with_child_span(op: "loan.extra_payment.apply", description: "Loan #{@account.accountable_id}") do |span|
          span.set_data(:loan_id, @account.accountable_id) rescue nil
          span.set_data(:created, created.size) rescue nil
        end
        tx = Sentry.get_current_scope.get_transaction
        tx&.set_measurement("loan.extra.created", created.size, "none")
        tx&.set_measurement("loan.extra.ms", ms, "millisecond")
      rescue NoMethodError; end
    end
    begin
      ActiveSupport::Notifications.instrument(
        "sure.loan.extra_payment.applied",
        loan_id: @account.accountable_id,
        amount: @amount.to_s,
        mode: @allocation_mode,
        ms: ms
      )
    rescue StandardError
    end
    Rails.logger.info({ at: "Loan::ApplyExtraPayment", account_id: @account.id, amount: @amount.to_s, mode: @allocation_mode, created: created.size, ms: ms }.to_json)
    Result.new(success?: true, installments: created)
  rescue => e
    Rails.logger.error({ at: "Loan::ApplyExtraPayment.error", account_id: @account.id, amount: @amount.to_s, error: e.message }.to_json)
    Result.new(success?: false, error: e.message)
  end

  private

    def average_principal_per_period(total_principal, period_count)
      count = [ period_count, 1 ].max
      total = total_principal.positive? ? total_principal : @account.loan_installments.pending.sum(:principal_amount).to_d
      return total / count if total.positive?

      1.to_d
    end
end
