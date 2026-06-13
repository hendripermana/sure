require "test_helper"

class ServiceMerchantTest < ActiveSupport::TestCase
  test "available services include the catalog and current family services only" do
    family = families(:dylan_family)
    other_family = families(:empty)
    catalog_service = ServiceMerchant.create!(
      name: "Catalog Service",
      subscription_category: "software",
      popular: true
    )
    family_service = ServiceMerchant.create!(
      name: "Family Service",
      subscription_category: "software",
      family: family
    )
    other_service = ServiceMerchant.create!(
      name: "Other Family Service",
      subscription_category: "software",
      family: other_family
    )
    unowned_custom_service = ServiceMerchant.create!(
      name: "Legacy Unowned Service",
      subscription_category: "software"
    )

    available = ServiceMerchant.available_to(family)

    assert_includes available, catalog_service
    assert_includes available, family_service
    assert_not_includes available, other_service
    assert_not_includes available, unowned_custom_service
  end

  test "stores a flexible default schedule without requiring one" do
    service = ServiceMerchant.new(
      name: "Flexible Service",
      subscription_category: "software",
      default_interval_count: 14,
      default_interval_unit: "day"
    )

    assert service.valid?
    assert_equal "14_day", service.billing_frequency
    assert_equal "Every 14 days", service.formatted_billing_frequency

    service.default_interval_unit = ""
    assert service.valid?
    assert_nil service.billing_frequency
    assert_equal "No default", service.formatted_billing_frequency
  end
end
