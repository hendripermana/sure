class DesignSystemComponent < ViewComponent::Base
  private
    def turbo_confirm_data(confirm)
      confirm.respond_to?(:to_data_attribute) ? confirm.to_data_attribute : confirm
    end
end
