class Loan::PlanBuilder
  Result = Struct.new(:success?, :installments, :error, keyword_init: true)

  def self.call!(account:, principal_amount:, rate_or_profit:, tenor_months:, payment_frequency:, schedule_method:, start_date:, balloon_amount: 0)
    new(account:, principal_amount:, rate_or_profit:, tenor_months:, payment_frequency:, schedule_method:, start_date:, balloon_amount:).call!
  end

  def initialize(account:, principal_amount:, rate_or_profit:, tenor_months:, payment_frequency:, schedule_method:, start_date:, balloon_amount: 0)
    @account = account
    @principal_amount = principal_amount
    @rate_or_profit = rate_or_profit
    @tenor_months = tenor_months
    @payment_frequency = payment_frequency
    @schedule_method = schedule_method
    @start_date = start_date
    @balloon_amount = balloon_amount.present? ? balloon_amount.to_d : 0.to_d
  end

  def call!
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    normalized_rate = if account.accountable.interest_free?
      0.to_d
    else
      Loan.normalize_rate(@rate_or_profit || 0)
    end

    rows = Loan::ScheduleGenerator.new(
      principal_amount: @principal_amount,
      rate_or_profit: normalized_rate,
      tenor_months: @tenor_months,
      payment_frequency: @payment_frequency,
      schedule_method: @schedule_method,
      start_date: @start_date,
      balloon_amount: @balloon_amount,
      loan_id: account.accountable_id
    ).generate

    installments = []
    ActiveRecord::Base.transaction do
      # Determine the last posted installment number and today-based cutoff
      last_posted_no = account.loan_installments.where(status: "posted").maximum(:installment_no) || 0

      # Remove only future planned rows: those due today or later OR with number beyond last_posted
      account.loan_installments
             .where(status: "planned")
             .where("due_date >= ? OR installment_no > ?", Date.current, last_posted_no)
             .delete_all

      rows.each_with_index do |row, idx|
        next if (idx + 1) <= last_posted_no # keep past rows intact

        installments << LoanInstallment.create!(
          account_id: account.id,
          installment_no: idx + 1,
          due_date: row.due_date,
          status: "planned",
          principal_amount: row.principal,
          interest_amount: row.interest,
          total_amount: row.total
        )
      end
    end

    ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round(1)
    begin
      ActiveSupport::Notifications.instrument(
        "sure.loan.plan.regenerate",
        loan_id: account.accountable_id,
        replaced_count: installments.size,
        ms: ms
      )
    rescue StandardError
    end
    if defined?(Sentry)
      begin
        Sentry.with_child_span(op: "loan.plan.build", description: "Loan #{account.accountable_id}") do |span|
          span.set_data(:loan_id, account.accountable_id) rescue nil
          span.set_data(:created, installments.size) rescue nil
        end
        tx = Sentry.get_current_scope.get_transaction
        tx&.set_measurement("loan.plan.created", installments.size, "none")
        tx&.set_measurement("loan.plan.ms", ms, "millisecond")
      rescue NoMethodError; end
    end
    Rails.logger.info({ at: "Loan::PlanBuilder", account_id: account.id, created: installments.size, ms: ms }.to_json)
    Result.new(success?: true, installments: installments)
  rescue => e
    Rails.logger.error({ at: "Loan::PlanBuilder.error", account_id: account.id, error: e.message }.to_json)
    Result.new(success?: false, error: e.message)
  end

  private
    def account
      @account
    end
end
