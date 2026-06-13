require "test_helper"

class LoanNotificationsTest < ActiveSupport::TestCase
  setup do
    @loan_account = accounts(:loan)
  end
  test "schedule generator emits notification" do
    events = []
    sub = ActiveSupport::Notifications.subscribe("sure.loan.schedule.generate") { |*args| events << ActiveSupport::Notifications::Event.new(*args) }
    Loan::ScheduleGenerator.new(principal_amount: 1000, rate_or_profit: 0.1, tenor_months: 6, start_date: Date.current, loan_id: @loan_account.accountable_id).generate
    assert events.any?, "expected schedule.generate event"
  ensure
    ActiveSupport::Notifications.unsubscribe(sub) if sub
  end

  test "plan builder emits notification" do
    events = []
    sub = ActiveSupport::Notifications.subscribe("sure.loan.plan.regenerate") { |*args| events << ActiveSupport::Notifications::Event.new(*args) }
    res = Loan::PlanBuilder.call!(
      account: @loan_account,
      principal_amount: 1000,
      rate_or_profit: 0.1,
      tenor_months: 6,
      payment_frequency: "MONTHLY",
      schedule_method: "ANNUITY",
      start_date: Date.current
    )
    assert res.success?
    assert events.any?, "expected plan.regenerate event"
  ensure
    ActiveSupport::Notifications.unsubscribe(sub) if sub
  end

  test "extra payment emits notification" do
    # seed at least one planned installment
    LoanInstallment.create!(account_id: @loan_account.id, installment_no: 1, due_date: Date.current + 1, status: "planned", principal_amount: 100, interest_amount: 0, total_amount: 100)
    events = []
    sub = ActiveSupport::Notifications.subscribe("sure.loan.extra_payment.applied") { |*args| events << ActiveSupport::Notifications::Event.new(*args) }
    res = Loan::ApplyExtraPayment.new(account: @loan_account, amount: 10, date: Date.current, allocation_mode: "reduce_term").call!
    assert res.success?
    assert events.any?, "expected extra_payment.applied event"
  ensure
    ActiveSupport::Notifications.unsubscribe(sub) if sub
  end
end
