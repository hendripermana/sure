require "test_helper"

class Recurring::ForecastTest < ActiveSupport::TestCase
  test "projects active commitments inside the requested horizon" do
    family = families(:dylan_family)
    subscription = subscription_plans(:netflix_subscription)
    subscription.update!(next_billing_at: 5.days.from_now.to_date)

    forecast = Recurring::Forecast.new(
      family,
      start_date: Date.current,
      end_date: 10.days.from_now.to_date
    )

    item = forecast.items.find { |candidate| candidate.commitment == subscription }

    assert item
    assert_equal subscription.next_billing_at, item.date
    assert_not item.actualized
    assert_operator forecast.projected_outflow, :>=, subscription.amount
  end

  test "does not project a commitment that already has an actual transaction" do
    family = families(:dylan_family)
    subscription = subscription_plans(:netflix_subscription)
    subscription.update!(next_billing_at: 5.days.from_now.to_date)
    match_key = "SubscriptionPlan:#{subscription.id}:#{subscription.next_billing_at}"
    transaction = Transaction.create!(
      extra: {
        "recurring_matches" => {
          match_key => {
            "commitment_id" => subscription.id,
            "expected_date" => subscription.next_billing_at.to_s
          }
        }
      }
    )
    accounts(:depository).entries.create!(
      name: subscription.name,
      amount: subscription.amount,
      currency: subscription.currency,
      date: subscription.next_billing_at,
      entryable: transaction
    )

    forecast = Recurring::Forecast.new(
      family,
      start_date: Date.current,
      end_date: 10.days.from_now.to_date
    )
    item = forecast.items.find { |candidate| candidate.commitment == subscription }

    assert item.actualized
    assert_not_includes forecast.projected_items, item
  end
end
