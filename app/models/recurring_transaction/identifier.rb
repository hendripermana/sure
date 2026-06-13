class RecurringTransaction
  class Identifier
    attr_reader :family

    def initialize(family)
      @family = family
    end

    # Identify and create/update recurring transactions for the family
    def identify_recurring_patterns
      three_months_ago = 3.months.ago.to_date

      # Get all transactions from the last 3 months
      entries_with_transactions = family.entries
        .joins(RecurringTransaction.transaction_join_sql)
        .where(entryable_type: "Transaction")
        .where("entries.date >= ?", three_months_ago)
        .where.not(transactions: { kind: Transaction::TRANSFER_KINDS })
        .includes(:entryable)
        .to_a

      # Group by account, merchant/name, amount (preserve sign), and currency.
      grouped_transactions = entries_with_transactions
        .select { |entry| entry.entryable.is_a?(Transaction) }
        .group_by do |entry|
          transaction = entry.entryable
          # Use merchant_id if present, otherwise use entry name
          identifier = transaction.merchant_id.present? ? [ :merchant, transaction.merchant_id ] : [ :name, entry.name ]
          [ entry.account_id, identifier, entry.amount.round(2), entry.currency ]
        end

      recurring_patterns = []

      grouped_transactions.each do |(account_id, identifier, amount, currency), entries|
        next if entries.size < 3  # Must have at least 3 occurrences

        # Check if the last occurrence was within the last 45 days
        last_occurrence = entries.max_by(&:date)
        next if last_occurrence.date < 45.days.ago.to_date

        cadence = calculate_short_cadence(entries)

        # Monthly patterns cluster by day-of-month. Short schedules instead use
        # stable day gaps and require at least four occurrences.
        days_of_month = entries.map { |e| e.date.day }.sort

        if cadence.present? || days_cluster_together?(days_of_month)
          expected_day = calculate_expected_day(days_of_month)

          # Unpack identifier - either [:merchant, id] or [:name, name_string]
          identifier_type, identifier_value = identifier

          pattern = {
            account_id: account_id,
            amount: amount,
            currency: currency,
            expected_day_of_month: expected_day,
            last_occurrence_date: last_occurrence.date,
            occurrence_count: entries.size,
            cadence_days: cadence,
            entries: entries
          }

          # Set either merchant_id or name based on identifier type
          if identifier_type == :merchant
            pattern[:merchant_id] = identifier_value
          else
            pattern[:name] = identifier_value
          end

          recurring_patterns << pattern
        end
      end

      processed_count = 0

      # Create or update RecurringTransaction records
      recurring_patterns.each do |pattern|
        # Build find conditions based on whether it's merchant-based or name-based
        find_conditions = {
          account_id: pattern[:account_id],
          amount: pattern[:amount],
          currency: pattern[:currency]
        }

        if pattern[:merchant_id].present?
          find_conditions[:merchant_id] = pattern[:merchant_id]
          find_conditions[:name] = nil
        else
          find_conditions[:name] = pattern[:name]
          find_conditions[:merchant_id] = nil
        end

        # Check if a manual recurring transaction already exists for this pattern
        # If so, we skip auto-creation to avoid duplicates, but we might want to update stats?
        # For now, let's assume manual overrides auto
        legacy_find_conditions = find_conditions.merge(account_id: nil)
        existing_manual =
          family.recurring_transactions.find_by(find_conditions.merge(manual: true)) ||
          family.recurring_transactions.find_by(legacy_find_conditions.merge(manual: true))

        if existing_manual
          existing_manual.update!(account_id: pattern[:account_id]) if existing_manual.account_id.blank?
          next
        end

        recurring_transaction =
          family.recurring_transactions.find_by(find_conditions) ||
          family.recurring_transactions.find_by(legacy_find_conditions)

        if recurring_transaction.nil? && RecurringTransactionSuppression.suppressed?(
          family: family,
          account_id: pattern[:account_id],
          merchant_id: pattern[:merchant_id],
          name: pattern[:name],
          amount: pattern[:amount],
          currency: pattern[:currency]
        )
          next
        end

        recurring_transaction ||= family.recurring_transactions.new(find_conditions)

        # Set the name or merchant_id on new records
        if recurring_transaction.new_record?
          recurring_transaction.account_id = pattern[:account_id]

          if pattern[:merchant_id].present?
            recurring_transaction.merchant_id = pattern[:merchant_id]
          else
            recurring_transaction.name = pattern[:name]
          end
        elsif recurring_transaction.account_id.blank?
          recurring_transaction.account_id = pattern[:account_id]
        end

        recurring_transaction.assign_attributes(
          expected_day_of_month: pattern[:expected_day_of_month],
          last_occurrence_date: pattern[:last_occurrence_date],
          next_expected_date: calculate_next_expected_date(
            pattern[:last_occurrence_date],
            pattern[:expected_day_of_month],
            cadence_days: pattern[:cadence_days]
          ),
          occurrence_count: pattern[:occurrence_count],
          status: recurring_transaction.new_record? ? "active" : recurring_transaction.status
        )

        recurring_transaction.save!
        processed_count += 1
      end

      processed_count
    end

    private
      # Check if days cluster together (within ~5 days variance)
      # Uses circular distance to handle month-boundary wrapping (e.g., 28, 29, 30, 31, 1, 2)
      def days_cluster_together?(days)
        return false if days.empty?

        # Calculate median as reference point
        median = calculate_expected_day(days)

        # Calculate circular distances from median
        circular_distances = days.map { |day| circular_distance(day, median) }

        # Calculate standard deviation of circular distances
        mean_distance = circular_distances.sum.to_f / circular_distances.size
        variance = circular_distances.map { |dist| (dist - mean_distance)**2 }.sum / circular_distances.size
        std_dev = Math.sqrt(variance)

        # Allow up to 5 days standard deviation
        std_dev <= 5
      end

      def calculate_short_cadence(entries)
        return nil if entries.size < 4

        dates = entries.map(&:date).sort
        gaps = dates.each_cons(2).map { |previous_date, date| (date - previous_date).to_i }
        median = gaps.sort[gaps.size / 2]
        return nil unless median.between?(1, 27)
        return nil unless gaps.all? { |gap| (gap - median).abs <= 2 }

        median
      end

      # Calculate circular distance between two days on a 31-day circle
      # Examples:
      #   circular_distance(1, 31) = 2  (wraps around: 31 -> 1 is 1 day forward)
      #   circular_distance(28, 2) = 5  (wraps: 28, 29, 30, 31, 1, 2)
      def circular_distance(day1, day2)
        linear_distance = (day1 - day2).abs
        wrap_distance = 31 - linear_distance
        [ linear_distance, wrap_distance ].min
      end

      # Calculate the expected day based on the most common day
      # Uses circular rotation to handle month-wrapping sequences (e.g., [29, 30, 31, 1, 2])
      def calculate_expected_day(days)
        return days.first if days.size == 1

        # Convert to 0-indexed (0-30 instead of 1-31) for modular arithmetic
        days_0 = days.map { |d| d - 1 }

        # Find the rotation (pivot) that minimizes span, making the cluster contiguous
        # This handles month-wrapping sequences like [29, 30, 31, 1, 2]
        best_pivot = 0
        min_span = Float::INFINITY

        (0..30).each do |pivot|
          rotated = days_0.map { |d| (d - pivot) % 31 }
          span = rotated.max - rotated.min

          if span < min_span
            min_span = span
            best_pivot = pivot
          end
        end

        # Rotate days using best pivot to create contiguous array
        rotated_days = days_0.map { |d| (d - best_pivot) % 31 }.sort

        # Calculate median on rotated, contiguous array
        mid = rotated_days.size / 2
        rotated_median = if rotated_days.size.odd?
          rotated_days[mid]
        else
          # For even count, average and round
          ((rotated_days[mid - 1] + rotated_days[mid]) / 2.0).round
        end

        # Map median back to original day space (unrotate) and convert to 1-indexed
        original_day = (rotated_median + best_pivot) % 31 + 1

        original_day
      end

      # Calculate next expected date
      def calculate_next_expected_date(last_date, expected_day, cadence_days: nil)
        return last_date + cadence_days.days if cadence_days.present?

        next_month = last_date.next_month

        begin
          Date.new(next_month.year, next_month.month, expected_day)
        rescue ArgumentError
          # If day doesn't exist in month, use last day of month
          next_month.end_of_month
        end
      end
  end
end
