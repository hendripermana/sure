module Recurring
  class Reconciler
    Result = Data.define(
      :commitment,
      :status,
      :expected_date,
      :expected_amount,
      :entries,
      :confidence,
      :detail
    )

    DATE_TOLERANCE = 3.days
    MISSING_GRACE = 3.days
    AMOUNT_TOLERANCE = 0.05
    RECONCILIATION_LOOKBACK = 45.days

    attr_reader :family, :as_of, :entry

    def initialize(family, as_of: Date.current, entry: nil)
      @family = family
      @as_of = as_of.to_date
      @entry = entry
    end

    def reconcile!
      ApplicationRecord.transaction do
        results = subscription_results + recurring_results
        results.each { |result| persist!(result) }

        ActiveSupport::Notifications.instrument(
          "sure.recurring.reconciled",
          family_id: family.id,
          as_of: as_of,
          counts: results.tally { |result| result.status }
        )

        results
      end
    end

    private
      def subscription_results
        expected_results = subscription_scope
          .where(status: %w[active trial])
          .where.not(next_billing_at: nil)
          .flat_map do |subscription|
            subscription_occurrences(subscription).map do |occurrence|
              build_result(subscription, occurrence[:date], occurrence[:amount])
            end
          end

        expected_results + unexpected_subscription_results
      end

      def subscription_occurrences(subscription)
        occurrences = subscription.subscription_renewals
          .where(billing_period_start: (as_of - RECONCILIATION_LOOKBACK)..as_of)
          .pluck(:billing_period_start, :template_amount)
          .map { |date, amount| { date: date, amount: amount } }

        if subscription.next_billing_at <= as_of
          occurrences << { date: subscription.next_billing_at, amount: subscription.amount }
        end

        occurrences.uniq { |occurrence| occurrence[:date] }
      end

      def unexpected_subscription_results
        subscription_scope
          .where(status: %w[paused cancelled expired])
          .filter_map do |subscription|
            entries = candidates_for(subscription, as_of)
            next if entries.empty?

            Result.new(
              commitment: subscription,
              status: "unexpected_renewal",
              expected_date: entries.first.date,
              expected_amount: subscription.amount,
              entries: entries,
              confidence: confidence_for(entries, subscription.amount),
              detail: "A charge was found while the subscription was #{subscription.status}."
            )
          end
      end

      def recurring_results
        recurring_scope.visible.active.filter_map do |recurring_transaction|
          expected_date = recurring_transaction.next_expected_date
          next if expected_date.blank? || expected_date > as_of

          build_result(recurring_transaction, expected_date, recurring_transaction.amount)
        end
      end

      def build_result(commitment, expected_date, expected_amount)
        entries = candidates_for(commitment, expected_date)
        status = classify(entries, expected_date, expected_amount)
        confidence = confidence_for(entries, expected_amount)

        Result.new(
          commitment: commitment,
          status: status,
          expected_date: expected_date,
          expected_amount: expected_amount,
          entries: entries,
          confidence: confidence,
          detail: detail_for(status, entries, expected_amount)
        )
      end

      def candidates_for(commitment, expected_date)
        scope = entry.present? ? family.entries.where(id: entry.id) : family.entries
        scope = scope
          .preload(:entryable)
          .where(entryable_type: "Transaction", currency: commitment.currency)
          .where(date: (expected_date - DATE_TOLERANCE)..(expected_date + DATE_TOLERANCE))

        scope = scope.where(account_id: commitment.account_id) if commitment.account_id.present?
        scope = scope.where("ABS(entries.amount) BETWEEN ? AND ?", commitment.amount.to_d.abs * 0.5, commitment.amount.to_d.abs * 1.5)

        if commitment.respond_to?(:merchant_id) && commitment.merchant_id.present?
          fallback_names = [
            commitment.name,
            commitment.merchant&.name
          ].compact.flat_map { |name| [ name, "Subscription: #{name}" ] }
            .map { |name| name.squish.downcase }
            .uniq

          scope.joins("INNER JOIN transactions ON transactions.id = entries.entryable_id")
            .where(
              "transactions.merchant_id = :merchant_id OR " \
              "(transactions.merchant_id IS NULL AND LOWER(entries.name) IN (:names))",
              merchant_id: commitment.merchant_id,
              names: fallback_names
            )
            .order(:date, :created_at)
            .to_a
        else
          scope.where("LOWER(entries.name) = ?", commitment.name.to_s.downcase)
            .order(:date, :created_at)
            .to_a
        end
      end

      def subscription_scope
        scope = family.subscription_plans.unarchived
        return scope unless entry.present?

        scope = scope.where(account_id: entry.account_id, currency: entry.currency)
        merchant_id = entry.entryable&.merchant_id
        merchant_id.present? ? scope.where(merchant_id: merchant_id) : scope
      end

      def recurring_scope
        scope = family.recurring_transactions
        return scope unless entry.present?

        scope = scope.where(account_id: entry.account_id, currency: entry.currency)
        merchant_id = entry.entryable&.merchant_id
        merchant_id.present? ? scope.where(merchant_id: merchant_id) : scope
      end

      def classify(entries, expected_date, expected_amount)
        return "duplicate" if entries.many?
        return expected_date + MISSING_GRACE < as_of ? "missed" : "pending" if entries.empty?

        difference = (entries.first.amount.to_d.abs - expected_amount.to_d.abs).abs
        threshold = [ expected_amount.to_d.abs * AMOUNT_TOLERANCE, 1.to_d ].max
        difference > threshold ? "amount_changed" : "paid"
      end

      def confidence_for(entries, expected_amount)
        return 0 if entries.empty?
        return 65 if entries.many?
        return 55 if expected_amount.to_d.zero?

        difference = (entries.first.amount.to_d.abs - expected_amount.to_d.abs).abs
        amount_score = 35 - [ ((difference / expected_amount.to_d.abs) * 100).round, 35 ].min
        (55 + amount_score).clamp(0, 100)
      end

      def detail_for(status, entries, expected_amount)
        case status
        when "duplicate"
          "#{entries.size} transactions matched one expected occurrence."
        when "missed"
          "No matching transaction arrived within the payment window."
        when "pending"
          "The expected date is still within the reconciliation grace period."
        when "amount_changed"
          "Expected #{expected_amount.to_d.to_s('F')}, observed #{entries.first.amount.to_d.abs.to_s('F')}."
        else
          "Matched to transaction #{entries.first.id}."
        end
      end

      def persist!(result)
        result.entries.each { |entry| link_entry!(entry, result) }
        if result.commitment.is_a?(SubscriptionPlan) && result.status != "unexpected_renewal"
          link_subscription_renewal!(result)
        end
        record_result_event!(result)
      end

      def link_entry!(entry, result)
        transaction = entry.entryable
        match_key = "#{result.commitment.class.name}:#{result.commitment.id}:#{result.expected_date}"
        matches = transaction.extra.fetch("recurring_matches", {})
        return if matches.key?(match_key)

        transaction.with_lock do
          latest_matches = transaction.extra.fetch("recurring_matches", {})
          transaction.update!(
            extra: transaction.extra.merge(
              "recurring_matches" => latest_matches.merge(
                match_key => {
                  "commitment_type" => result.commitment.class.name,
                  "commitment_id" => result.commitment.id,
                  "expected_date" => result.expected_date.to_s,
                  "status" => result.status,
                  "confidence" => result.confidence,
                  "reconciled_at" => Time.current.iso8601
                }
              )
            )
          )
        end
      end

      def link_subscription_renewal!(result)
        subscription = result.commitment
        renewal = subscription.subscription_renewals.find_or_initialize_by(
          billing_period_start: result.expected_date
        )

        if renewal.new_record?
          renewal.assign_attributes(
            cycle_number: subscription.next_cycle_number,
            account_id: subscription.account_id,
            billing_period_end: subscription.calculate_next_billing_date || result.expected_date,
            template_amount: subscription.amount,
            actual_amount: result.entries.first&.amount&.abs || subscription.amount,
            admin_fee: subscription.default_admin_fee || 0,
            currency: subscription.currency,
            status: "pending"
          )
        end

        if result.entries.one? && result.status.in?(%w[paid amount_changed])
          renewal.mark_paid!(
            paid_at: result.entries.first.date,
            actual_amount: result.entries.first.amount.abs,
            entry_id: result.entries.first.id
          )
          if subscription.next_billing_at == result.expected_date && subscription.active_or_trial?
            subscription.mark_as_renewed!(result.entries.first.date)
          end
        elsif result.status == "missed"
          renewal.mark_failed!(notes: result.detail)
        else
          renewal.save!
        end
      end

      def record_result_event!(result)
        severity = result.status.in?(%w[missed duplicate amount_changed unexpected_renewal]) ? "warning" : "info"
        key = "#{result.commitment.class.name}:#{result.commitment.id}:#{result.expected_date}:#{result.status}"

        EventRecorder.record!(
          record: result.commitment,
          event: "recurring.#{result.status}",
          key: key,
          title: result.status.humanize,
          detail: result.detail,
          severity: severity,
          metadata: {
            expected_date: result.expected_date,
            expected_amount: result.expected_amount,
            observed_amount: result.entries.one? ? result.entries.first.amount.to_d.abs : nil,
            entry_count: result.entries.size,
            entry_ids: result.entries.map(&:id),
            confidence: result.confidence
          }
        )
      end
  end
end
