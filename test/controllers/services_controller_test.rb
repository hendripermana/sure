require "test_helper"

class ServicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @other_family = families(:empty)
    sign_in @user
  end

  test "index only exposes catalog and current family services" do
    catalog_service = create_service(name: "Catalog Visible", popular: true)
    family_service = create_service(name: "Family Visible", family: @family)
    other_service = create_service(name: "Other Family Hidden", family: @other_family)

    get services_url

    assert_response :success
    assert_select "[data-service-id='#{catalog_service.id}']"
    assert_select "[data-service-id='#{family_service.id}']"
    assert_select "[data-service-id='#{other_service.id}']", count: 0
  end

  test "create assigns the service to the current family" do
    assert_difference -> { ServiceMerchant.owned_by(@family).count }, 1 do
      post services_url, params: {
        service_merchant: {
          name: "Private Service",
          subscription_category: "software"
        }
      }
    end

    assert_redirected_to services_url
    assert_equal @family, ServiceMerchant.find_by!(name: "Private Service").family
  end

  test "cannot edit another family service" do
    other_service = create_service(name: "Other Family Protected", family: @other_family)

    get edit_service_url(other_service)

    assert_response :not_found
  end

  private

    def create_service(name:, family: nil, popular: false)
      ServiceMerchant.create!(
        name: name,
        subscription_category: "software",
        family: family,
        popular: popular
      )
    end
end
