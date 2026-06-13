module Recurring
  class Assessment
    attr_reader :recurring_transaction

    def initialize(recurring_transaction)
      @recurring_transaction = recurring_transaction
    end

    def score
      @score ||= [
        occurrence_score,
        identity_score,
        account_score,
        schedule_score,
        amount_score,
        recency_score
      ].sum.clamp(0, 100)
    end

    def label
      return "High" if score >= 80
      return "Medium" if score >= 55

      "Low"
    end

    def evidence
      {
        occurrence_count: recurring_transaction.occurrence_count,
        matched_transactions: matching_entries.size,
        merchant_or_name: recurring_transaction.merchant&.name || recurring_transaction.name,
        account: recurring_transaction.account&.name,
        amount_range: amount_range,
        last_occurrence_date: recurring_transaction.last_occurrence_date,
        next_expected_date: recurring_transaction.next_expected_date
      }
    end

    def matching_entries
      @matching_entries ||= recurring_transaction.matching_transactions.limit(6).to_a
    end

    def reviewed?
      recurring_transaction.audit_logs.where(event: "recurring.confirmed").exists?
    end

    private
      def occurrence_score
        [ recurring_transaction.occurrence_count * 10, 30 ].min
      end

      def identity_score
        recurring_transaction.merchant_id.present? ? 20 : 12
      end

      def account_score
        recurring_transaction.account_id.present? ? 15 : 0
      end

      def schedule_score
        matching_entries.size >= 3 ? 15 : matching_entries.size * 4
      end

      def amount_score
        return 10 unless recurring_transaction.has_amount_variance?

        average = recurring_transaction.expected_amount_avg.to_d.abs
        return 0 if average.zero?

        spread = recurring_transaction.expected_amount_max.to_d - recurring_transaction.expected_amount_min.to_d
        (15 - ((spread.abs / average) * 100).round).clamp(0, 15)
      end

      def recency_score
        return 0 if recurring_transaction.last_occurrence_date.blank?
        return 5 if recurring_transaction.last_occurrence_date < 3.months.ago.to_date

        10
      end

      def amount_range
        minimum = recurring_transaction.expected_amount_min || recurring_transaction.amount
        maximum = recurring_transaction.expected_amount_max || recurring_transaction.amount
        [ minimum, maximum ]
      end
  end
end
