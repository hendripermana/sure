class SubscriptionRenewalJob < ApplicationJob
  queue_as :high_priority

  # Retry strategy for failed jobs
  retry_on ActiveRecord::Deadlocked, wait: :exponentially_longer, attempts: 5
  retry_on ActiveRecord::LockWaitTimeout, wait: :exponentially_longer, attempts: 3
  retry_on ActiveRecord::ConnectionNotEstablished, wait: 2.seconds, attempts: 3
  retry_on Redis::ConnectionError, wait: 2.seconds, attempts: 3

  # Handle record not found gracefully
  discard_on ActiveRecord::RecordNotFound

  def perform(date = Date.current)
    Rails.logger.info("Starting subscription renewals for #{date}")

    reminder_policy = SubscriptionPlan::ReminderPolicy.new(date: date)

    # Process renewals for the specified date
    process_renewals_for_date(date)

    # Send renewal and trial reminders through the idempotent audit ledger.
    reminder_counts = reminder_policy.deliver_upcoming!

    # Process trial expirations
    process_trial_expirations(date, reminder_policy: reminder_policy)

    # Process subscription expirations
    process_subscription_expirations(date)

    Rails.logger.info("Completed subscription renewals for #{date}")
    { reminders: reminder_counts }
  end

  private

    def process_renewals_for_date(date)
      Rails.logger.info("Processing renewals for #{date}")

      # Find subscriptions renewing today
      subscriptions_renewing = SubscriptionPlan.active.where(next_billing_at: date)

      subscriptions_renewing.find_each do |subscription|
        process_subscription_renewal(subscription, date)
      end

      Rails.logger.info("Processed #{subscriptions_renewing.count} renewals for #{date}")
    end

    def process_subscription_renewal(subscription, date)
      Rails.logger.info("Processing renewal for subscription #{subscription.id} (#{subscription.name})")

      begin
        if subscription.auto_renewal_enabled?
          if subscription.payment_method_auto?
            # Process Stripe payment
            process_stripe_renewal(subscription)
          else
            # Manual renewal using RenewalForm
            form = SubscriptionPlan::RenewalForm.new(
              subscription_plan: subscription,
              account_id: subscription.account_id,
              actual_amount: subscription.amount,
              admin_fee: subscription.default_admin_fee || 0,
              paid_at: date,
              payment_method: subscription.payment_method,
              currency: subscription.currency
            )
            unless form.create
              raise "Failed to create manual renewal: #{form.errors.full_messages.join(', ')}"
            end
          end
        else
          # Auto-renew disabled - mark as expired if past due
          if subscription.cancelled?
            subscription.expire!
          else
            # Send renewal reminder
            SubscriptionMailer.renewal_reminder(subscription).deliver_later
          end
        end

        Rails.logger.info("Successfully processed renewal for subscription #{subscription.id}")

      rescue => e
        Rails.logger.error("Failed to process renewal for subscription #{subscription.id}: #{e.message}")
        handle_renewal_failure(subscription, e)
      end
    end

    def process_stripe_renewal(subscription)
      return unless subscription.stripe_subscription_id.present?

      begin
        # Check subscription status with Stripe
        stripe_subscription = Stripe::Subscription.retrieve(subscription.stripe_subscription_id)

        if stripe_subscription.status == "active"
          billing_period_start = subscription.next_billing_at || Date.current
          billing_period_end = subscription.calculate_next_billing_date || billing_period_start

          ActiveRecord::Base.transaction do
            create_stripe_transaction(
              subscription,
              stripe_subscription,
              billing_period_start: billing_period_start,
              billing_period_end: billing_period_end
            )

            # Advance only after the accounting entry and renewal record are durable.
            subscription.mark_as_renewed!
          end

          # Send confirmation email
          SubscriptionMailer.renewal_confirmation(subscription).deliver_later

          Rails.logger.info("Stripe subscription #{subscription.id} renewed successfully")
        else
          # Subscription is not active, mark as failed
          subscription.mark_payment_failed!
          SubscriptionMailer.payment_failed(subscription, "Subscription status: #{stripe_subscription.status}").deliver_later

          Rails.logger.warn("Stripe subscription #{subscription.id} has status: #{stripe_subscription.status}")
        end

      rescue Stripe::CardError => e
        # Payment failed
        subscription.mark_payment_failed!
        SubscriptionMailer.payment_failed(subscription, e.message).deliver_later

        Rails.logger.error("Stripe payment failed for subscription #{subscription.id}: #{e.message}")

      rescue Stripe::StripeError => e
        # Other Stripe error
        Rails.logger.error("Stripe error for subscription #{subscription.id}: #{e.message}")
        raise e # Re-raise to trigger retry

      rescue => e
        # Unknown error
        Rails.logger.error("Unknown error processing Stripe renewal for subscription #{subscription.id}: #{e.message}")
        raise e # Re-raise to trigger retry
      end
    end

    def create_stripe_transaction(subscription, stripe_subscription, billing_period_start: subscription.next_billing_at || Date.current, billing_period_end: subscription.calculate_next_billing_date || Date.current)
      invoice_id = stripe_invoice_id(stripe_subscription)

      entry = subscription.account.entries.create!(
        name: "Subscription: #{subscription.name}",
        date: Date.current,
        amount: subscription.amount,
        currency: subscription.currency,
        notes: "Stripe subscription renewal",
        entryable: Transaction.new(
          kind: "standard",
          category: find_subscription_category(subscription.family),
          merchant: subscription.merchant,
          extra: {
            subscription_plan_id: subscription.id,
            stripe_subscription_id: subscription.stripe_subscription_id,
            stripe_invoice_id: invoice_id
          }.compact
        )
      )

      subscription.subscription_renewals.create!(
        cycle_number: subscription.next_cycle_number,
        account: subscription.account,
        entry: entry,
        billing_period_start: billing_period_start,
        billing_period_end: billing_period_end,
        paid_at: Date.current,
        template_amount: subscription.amount,
        actual_amount: subscription.amount,
        admin_fee: subscription.default_admin_fee || 0,
        currency: subscription.currency,
        status: "paid",
        payment_method: subscription.payment_method,
        metadata: {
          stripe_subscription_id: subscription.stripe_subscription_id,
          stripe_invoice_id: invoice_id
        }.compact
      )
    end

    def stripe_invoice_id(stripe_subscription)
      invoice = stripe_subscription.latest_invoice
      invoice.respond_to?(:id) ? invoice.id : invoice
    end

    # Safely find or create subscription category scoped to family
    def find_subscription_category(family)
      return nil unless family.present?

      # First try to find existing category
      category = family.categories.find_by(name: "Subscription Fees", classification: "expense")
      return category if category.present?

      # Create only if not exists, with proper validation
      family.categories.create!(
        name: "Subscription Fees",
        classification: "expense"
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("Failed to create Subscription Fees category: #{e.message}")
      # Fall back to finding any expense category or nil
      family.categories.find_by(classification: "expense")
    end

    def handle_renewal_failure(subscription, error)
      # Track failed renewal
      subscription.update!(
        failed_payment_alert_sent: true,
        status: "payment_failed"
      )

      # Send failure notification
      SubscriptionMailer.payment_failed(subscription, error.message).deliver_later

      # Track in analytics
      Sentry.capture_message(
        "Subscription renewal failed",
        level: :error,
        tags: {
          subscription_id: subscription.id,
          family_id: subscription.family.id
        },
        extra: {
          error_message: error.message,
          subscription_details: {
            name: subscription.name,
            amount: subscription.amount,
            billing_cycle: subscription.billing_cycle
          }
        }
      )
    end

    def process_trial_expirations(date, reminder_policy: SubscriptionPlan::ReminderPolicy.new(date: date))
      Rails.logger.info("Processing trial expirations for #{date}")

      # Find trials ending today
      trials_ending = SubscriptionPlan.where(status: %w[trial active], trial_ends_at: date)

      trials_ending.find_each do |subscription|
        reminder_policy.deliver_trial_expired!(subscription)

        if subscription.auto_renewal_enabled?
          # Convert trial to active subscription
          subscription.resume!
          Rails.logger.info("Converted trial to active: #{subscription.id}")
        else
          # Trial ended, subscription should be cancelled
          subscription.cancel!
          Rails.logger.info("Cancelled expired trial: #{subscription.id}")
        end
      end
    end

    def process_subscription_expirations(date)
      Rails.logger.info("Processing subscription expirations for #{date}")

      # Find subscriptions that should expire today
      subscriptions_to_expire = SubscriptionPlan.where(
        status: "cancelled",
        expires_at: date
      )

      subscriptions_to_expire.find_each do |subscription|
        subscription.expire!
        Rails.logger.info("Expired subscription: #{subscription.id}")
      end
    end
end
