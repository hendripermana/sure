class Balance::SyncCache
  def initialize(account, min_date: nil, max_date: nil)
    @account = account
    @min_date = min_date
    @max_date = max_date
  end

  def get_valuation(date)
    converted_entries.find { |e| e.date == date && e.valuation? }
  end

  def get_holdings(date)
    converted_holdings.select { |h| h.date == date }
  end

  def get_entries(date)
    converted_entries.select { |e| e.date == date && (e.transaction? || e.trade?) }
  end

  private
    attr_reader :account, :min_date, :max_date

    def converted_entries
      @converted_entries ||= begin
        scope = account.entries.excluding_split_parents.order(:date)
        scope = scope.where("date >= ?", min_date) if min_date
        scope = scope.where("date <= ?", max_date) if max_date

        scope.to_a.map do |e|
          converted_entry = e.dup
          converted_entry.amount = converted_entry.amount_money.exchange_to(
            account.currency,
            date: e.date,
            fallback_rate: 1
          ).amount
          converted_entry.currency = account.currency
          converted_entry
        end
      end
    end

    def converted_holdings
      @converted_holdings ||= begin
        scope = account.holdings
        # FIX: We need holdings from ONE DAY BEFORE min_date for market value change calculation
        # forward_calculator.rb: market_value_change_on_date calls holdings_value_for_date(date.prev_day)
        actual_min_date = min_date ? min_date - 1.day : nil

        scope = scope.where("date >= ?", actual_min_date) if actual_min_date
        scope = scope.where("date <= ?", max_date) if max_date

        scope.map do |h|
          converted_holding = h.dup
          converted_holding.amount = converted_holding.amount_money.exchange_to(
            account.currency,
            date: h.date,
            fallback_rate: 1
          ).amount
          converted_holding.currency = account.currency
          converted_holding
        end
      end
    end
end
