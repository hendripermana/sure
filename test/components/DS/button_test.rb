# frozen_string_literal: true

require "test_helper"

class DS::ButtonTest < ViewComponent::TestCase
  test "accepts plain string confirm text" do
    render_inline(
      DS::Button.new(
        text: "Cancel",
        href: "/subscription_plans/demo/cancel",
        method: :patch,
        confirm: "Are you sure?"
      )
    )

    assert_text "Cancel"
    assert_selector "[data-turbo-confirm='Are you sure?']"
  end

  test "accepts custom confirm payloads" do
    render_inline(
      DS::Button.new(
        text: "Delete",
        href: "/subscription_plans/demo",
        method: :delete,
        confirm: CustomConfirm.for_resource_deletion("subscription")
      )
    )

    assert_text "Delete"
    assert_includes rendered_content, "Delete Subscription?"
  end
end
