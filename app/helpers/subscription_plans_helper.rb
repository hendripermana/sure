module SubscriptionPlansHelper
  def subscription_row_class(subscription)
    base = "group cursor-pointer border-l-4 border-transparent transition-colors hover:bg-container-hover"
    return base unless subscription.present?

    days_until = subscription.days_until_renewal

    if subscription.cancelled? || subscription.expired?
      class_names(base, "border-l-gray-300 bg-container-inset/60 opacity-75 theme-dark:border-l-gray-700")
    elsif subscription.paused?
      class_names(base, "border-l-yellow-500 bg-yellow-tint-5 theme-dark:bg-yellow-tint-10")
    elsif days_until.present? && days_until <= 3 && subscription.active?
      class_names(base, "border-l-orange-500 bg-orange-tint-5 theme-dark:bg-orange-tint-10")
    else
      base
    end
  end

  # Returns the emoji category icon for either a legacy Service or a ServiceMerchant
  def service_icon(service)
    return "📋" unless service.present?
    service.respond_to?(:category_icon) ? service.category_icon : "📋"
  end

  # Normalized category label for a subscription's service/merchant
  def subscription_service_category(subscription)
    service = subscription.service_merchant
    return nil unless service.present?

    if service.respond_to?(:subscription_category)
      service.subscription_category
    else
      service.respond_to?(:category) ? service.category : nil
    end
  end

  def status_color_class(status)
    case status
    when "active"
      "bg-green-100 text-green-800"
    when "trial"
      "bg-blue-100 text-blue-800"
    when "paused"
      "bg-yellow-100 text-yellow-800"
    when "cancelled", "expired"
      "bg-gray-100 text-gray-800"
    when "payment_failed"
      "bg-red-100 text-red-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  def subscription_lifecycle_label(subscription)
    return "Cancels at renewal" if subscription.pending_cancellation?

    case subscription.status
    when "payment_failed"
      "Payment failed"
    else
      subscription.status.humanize
    end
  end

  def subscription_lifecycle_icon(subscription)
    return "calendar-x" if subscription.pending_cancellation?

    case subscription.status
    when "active"
      "check-circle-2"
    when "trial"
      "sparkles"
    when "paused"
      "pause-circle"
    when "cancelled", "expired"
      "x-circle"
    when "payment_failed"
      "alert-triangle"
    when "pending"
      "clock"
    else
      "circle"
    end
  end

  def subscription_lifecycle_badge_class(subscription)
    if subscription.pending_cancellation?
      return "border-orange-200 bg-orange-50 text-orange-700 theme-dark:border-orange-900/60 theme-dark:bg-orange-tint-10 theme-dark:text-orange-200"
    end

    case subscription.status
    when "active"
      "border-green-200 bg-green-50 text-green-700 theme-dark:border-green-900/60 theme-dark:bg-green-tint-10 theme-dark:text-green-200"
    when "trial"
      "border-blue-200 bg-blue-50 text-blue-700 theme-dark:border-blue-900/60 theme-dark:bg-blue-tint-10 theme-dark:text-blue-200"
    when "paused"
      "border-yellow-200 bg-yellow-50 text-yellow-800 theme-dark:border-yellow-900/60 theme-dark:bg-yellow-tint-10 theme-dark:text-yellow-200"
    when "cancelled", "expired"
      "border-gray-200 bg-gray-100 text-gray-700 theme-dark:border-gray-800 theme-dark:bg-gray-900/50 theme-dark:text-gray-300"
    when "payment_failed"
      "border-red-200 bg-red-50 text-red-700 theme-dark:border-red-900/60 theme-dark:bg-red-tint-10 theme-dark:text-red-200"
    else
      "border-primary bg-surface text-secondary"
    end
  end

  def subscription_billing_state_label(subscription)
    return "Final cycle" if subscription.pending_cancellation?
    return "Renewal paused" if subscription.paused?
    return "Ended" if subscription.cancelled?
    return "Expired" if subscription.expired?
    return "Payment failed" if subscription.payment_failed?

    subscription.billing_state.to_s.humanize
  end

  def subscription_billing_state_dot_class(subscription)
    state = if subscription.paused?
      :paused
    elsif subscription.cancelled? || subscription.expired?
      :ended
    elsif subscription.payment_failed?
      :payment_failed
    else
      subscription.billing_state
    end

    case state
    when :paid
      "bg-green-500"
    when :upcoming
      "bg-blue-500"
    when :open_for_payment
      "bg-orange-500"
    when :overdue, :payment_failed
      "bg-red-500"
    when :paused
      "bg-yellow-500"
    when :ended
      "bg-gray-400"
    else
      "bg-secondary"
    end
  end

  def billing_cycle_options
    SubscriptionPlan.billing_cycles.keys.map { |k| [ k.humanize, k ] }
  end

  def recurring_interval_unit_options
    [
      [ "Days", "day" ],
      [ "Weeks", "week" ],
      [ "Months", "month" ],
      [ "Years", "year" ],
      [ "One-time", "once" ]
    ]
  end

  def status_options
    SubscriptionPlan.statuses.keys.map { |k| [ k.humanize, k ] }
  end

  def payment_method_options
    SubscriptionPlan.payment_methods.keys.map { |k| [ k.humanize, k ] }
  end
end
