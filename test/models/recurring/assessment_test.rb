require "test_helper"

class Recurring::AssessmentTest < ActiveSupport::TestCase
  test "scores recurring evidence and exposes a label" do
    recurring_transaction = recurring_transactions(:netflix_subscription)
    assessment = Recurring::Assessment.new(recurring_transaction)

    assert_includes 0..100, assessment.score
    assert_includes %w[Low Medium High], assessment.label
    assert_equal recurring_transaction.occurrence_count, assessment.evidence[:occurrence_count]
    assert assessment.evidence.key?(:matched_transactions)
  end

  test "reports whether a pattern was explicitly reviewed" do
    recurring_transaction = recurring_transactions(:netflix_subscription)
    assessment = Recurring::Assessment.new(recurring_transaction)

    assert_not assessment.reviewed?

    recurring_transaction.confirm_as_recurring!

    assert Recurring::Assessment.new(recurring_transaction).reviewed?
    assert_equal 1, recurring_transaction.audit_logs.where(event: "recurring.confirmed").count

    recurring_transaction.confirm_as_recurring!

    assert_equal 1, recurring_transaction.audit_logs.where(event: "recurring.confirmed").count
  end
end
