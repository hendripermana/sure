class SubscriptionMailer < ApplicationMailer
  layout "mailer"

  # Renewal reminder email
  def renewal_reminder(subscription, days_until_renewal = 0)
    @subscription = subscription
    @days_until_renewal = days_until_renewal
    @family = subscription.family

    subject = case days_until_renewal
    when 0
      "Your #{subscription.name} subscription renews today!"
    when 1
      "Reminder: Your #{subscription.name} subscription renews tomorrow"
    else
      "Reminder: Your #{subscription.name} subscription renews in #{days_until_renewal} days"
    end

    recipient = safe_recipient_email(@family)
    return unless recipient.present?

    mail(to: recipient, subject: subject)
  end

  # Payment failed notification
  def payment_failed(subscription, error_message = nil)
    @subscription = subscription
    @error_message = error_message
    @family = subscription.family

    recipient = safe_recipient_email(@family)
    return unless recipient.present?

    mail(to: recipient, subject: "Payment failed for #{subscription.name}")
  end

  # Renewal confirmation
  def renewal_confirmation(subscription)
    @subscription = subscription
    @family = subscription.family

    recipient = safe_recipient_email(@family)
    return unless recipient.present?

    mail(to: recipient, subject: "Your #{subscription.name} has been renewed!")
  end

  # Trial ending notification
  def trial_ending(subscription, days_left = 0)
    @subscription = subscription
    @days_left = days_left
    @family = subscription.family

    recipient = safe_recipient_email(@family)
    return unless recipient.present?

    mail(to: recipient, subject: "Your #{subscription.name} trial ends in #{days_left} days")
  end

  # Trial expired notification
  def trial_expired(subscription)
    @subscription = subscription
    @family = subscription.family

    recipient = safe_recipient_email(@family)
    return unless recipient.present?

    mail(to: recipient, subject: "Your #{subscription.name} trial has expired")
  end

  def recurring_anomaly(family, commitment, event)
    @family = family
    @commitment = commitment
    @event_data = event.changeset

    recipient = safe_recipient_email(family)
    return unless recipient.present?

    mail(
      to: recipient,
      subject: "Recurring payment needs attention: #{commitment.name}"
    )
  end

  # Subscription cancelled confirmation
  def subscription_cancelled(subscription)
    @subscription = subscription
    @family = subscription.family

    recipient = safe_recipient_email(@family)
    return unless recipient.present?

    mail(to: recipient, subject: "Your #{subscription.name} subscription has been cancelled")
  end

  # Welcome email for new subscription
  def welcome_subscription(subscription)
    @subscription = subscription
    @family = subscription.family

    recipient = safe_recipient_email(@family)
    return unless recipient.present?

    mail(to: recipient, subject: "Welcome to #{subscription.name}!")
  end

  # Monthly subscription summary
  def monthly_summary(family, subscriptions, month_date = Date.current)
    @family = family
    @subscriptions = subscriptions
    @month_date = month_date
    @total_spent = subscriptions.sum(&:amount)

    mail(
      to: @family.primary_user&.email,
      subject: "Your subscription summary for #{month_date.strftime('%B %Y')}"
    )
  end

  private

    # Safely get recipient email - only use family's primary user
    # Never fall back to arbitrary account users for security
    def safe_recipient_email(family)
      return nil unless family.present?

      primary_email = family.primary_user&.email
      return primary_email if primary_email.present?

      # Log warning if no primary user email found
      Rails.logger.warn("No primary user email found for family #{family.id}")
      nil
    end

    def format_amount(amount, currency = "USD")
      number_to_currency(amount, unit: currency)
    end
end
