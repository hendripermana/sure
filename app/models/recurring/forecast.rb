module Recurring
  class Forecast
    Item = Data.define(:commitment, :date, :amount, :currency, :kind, :actualized)

    attr_reader :family, :start_date, :end_date

    def initialize(family, start_date: Date.current, end_date: 30.days.from_now.to_date)
      @family = family
      @start_date = start_date.to_date
      @end_date = end_date.to_date
    end

    def items
      @items ||= (subscription_items + recurring_items).sort_by(&:date)
    end

    def projected_items
      items.reject(&:actualized)
    end

    def projected_outflow
      projected_items
        .select { |item| item.currency == family.currency }
        .sum { |item| item.amount.to_d.abs }
    end

    private
      def subscription_items
        family.subscription_plans.unarchived
          .where(status: %w[active trial])
          .where.not(next_billing_at: nil)
          .flat_map do |subscription|
            occurrence_dates(subscription.next_billing_at, subscription.schedule).map do |date|
              build_item(subscription, date, subscription.amount, "subscription")
            end
          end
      end

      def recurring_items
        family.recurring_transactions.visible.active
          .where.not(next_expected_date: nil)
          .flat_map do |recurring_transaction|
            occurrence_dates(recurring_transaction.next_expected_date, recurring_transaction.schedule).map do |date|
              build_item(
                recurring_transaction,
                date,
                recurring_transaction.expected_amount_avg || recurring_transaction.amount,
                recurring_transaction.transfer? ? "transfer" : "recurring"
              )
            end
          end
      end

      def occurrence_dates(first_date, schedule)
        date = first_date.to_date
        dates = []

        while date <= end_date
          dates << date if date >= start_date
          date = schedule.advance(date)
          break if date.blank?
        end

        dates
      end

      def build_item(commitment, date, amount, kind)
        Item.new(
          commitment: commitment,
          date: date,
          amount: amount,
          currency: commitment.currency,
          kind: kind,
          actualized: actualized?(commitment, date)
        )
      end

      def actualized?(commitment, date)
        family.transactions
          .where("transactions.extra -> 'recurring_matches' IS NOT NULL")
          .where(
            "transactions.extra -> 'recurring_matches' @> ?::jsonb",
            {
              "#{commitment.class.name}:#{commitment.id}:#{date}" => {
                "commitment_id" => commitment.id,
                "expected_date" => date.to_s
              }
            }.to_json
          )
          .exists?
      end
  end
end
