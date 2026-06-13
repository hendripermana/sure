require "test_helper"

class FamilyTest < ActiveSupport::TestCase
  test "primary user prefers an active administrator" do
    family = families(:dylan_family)

    assert family.primary_user.active?
    assert family.primary_user.admin?
  end

  test "available transaction merchants include services used by subscriptions" do
    family = families(:dylan_family)
    service = ServiceMerchant.create!(
      name: "Family Subscription Merchant",
      subscription_category: "software"
    )
    subscription_plans(:netflix_subscription).update!(merchant: service)

    assert_includes family.available_transaction_merchants, service
    assert_includes family.available_transaction_merchants, family.merchants.first
  end

  include SyncableInterfaceTest

  def setup
    @syncable = families(:dylan_family)
  end
end
