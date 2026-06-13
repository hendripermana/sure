class Provider::Stripe::SubscriptionEventProcessor < Provider::Stripe::EventProcessor
  Error = Class.new(StandardError)

  def process
    if subscription_plan
      if event_id.present? && event_created_at.present?
        subscription_plan.apply_stripe_event!(
          subscription,
          event_id: event_id,
          event_type: event_type,
          event_created_at: event_created_at
        )
      else
        subscription_plan.sync_from_stripe_subscription!(subscription)
      end
      return
    end

    raise Error, "Family not found for Stripe customer ID: #{subscription.customer}" unless family

    family.subscription.update(
      stripe_id: subscription.id,
      status: subscription.status,
      interval: subscription_details.plan.interval,
      amount: subscription_details.plan.amount / 100.0, # Stripe returns cents, we report dollars
      currency: subscription_details.plan.currency.upcase,
      current_period_ends_at: Time.at(subscription_details.current_period_end)
    )
  end

  private
    def family
      Family.find_by(stripe_customer_id: subscription.customer)
    end

    def subscription_plan
      @subscription_plan ||= SubscriptionPlan.unscoped.find_by(stripe_subscription_id: subscription.id)
    end

    def subscription_details
      event_data.items.data.first
    end

    def subscription
      event_data
    end
end
