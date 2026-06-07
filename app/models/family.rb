class Family < ApplicationRecord
  include PlaidConnectable, SimplefinConnectable, LunchflowConnectable, Syncable, AutoTransferMatchable, Subscribeable, KpiCalculable

  DATE_FORMATS = [
    [ "MM-DD-YYYY", "%m-%d-%Y" ],
    [ "DD.MM.YYYY", "%d.%m.%Y" ],
    [ "DD-MM-YYYY", "%d-%m-%Y" ],
    [ "YYYY-MM-DD", "%Y-%m-%d" ],
    [ "DD/MM/YYYY", "%d/%m/%Y" ],
    [ "YYYY/MM/DD", "%Y/%m/%d" ],
    [ "MM/DD/YYYY", "%m/%d/%Y" ],
    [ "D/MM/YYYY", "%e/%m/%Y" ],
    [ "YYYY.MM.DD", "%Y.%m.%d" ],
    [ "YYYYMMDD", "%Y%m%d" ]
  ].freeze

  has_many :users, dependent: :destroy
  has_many :accounts, dependent: :destroy
  has_many :invitations, dependent: :destroy

  has_many :imports, dependent: :destroy
  has_many :family_exports, dependent: :destroy

  has_many :entries, through: :accounts
  has_many :transactions, through: :accounts
  has_many :rules, dependent: :destroy
  has_many :trades, through: :accounts
  has_many :holdings, through: :accounts

  has_many :tags, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :merchants, dependent: :destroy, class_name: "FamilyMerchant"

  has_many :budgets, dependent: :destroy
  has_many :budget_categories, through: :budgets

  has_many :llm_usages, dependent: :destroy
  has_many :recurring_transactions, dependent: :destroy
  has_many :recurring_transaction_suppressions, dependent: :destroy
  has_many :subscription_plans, dependent: :destroy

  def primary_user
    users.where(active: true).order(
      Arel.sql("CASE role WHEN 'super_admin' THEN 0 WHEN 'admin' THEN 1 ELSE 2 END"),
      :created_at
    ).first
  end

  validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }
  validates :date_format, inclusion: { in: DATE_FORMATS.map(&:last) }

  def assigned_merchants
    merchant_ids = transactions.where.not(merchant_id: nil).pluck(:merchant_id).uniq
    Merchant.where(id: merchant_ids)
  end

  def available_transaction_merchants
    service_ids = subscription_plans.where.not(merchant_id: nil).select(:merchant_id)
    Merchant.where(id: merchants.select(:id)).or(Merchant.where(id: service_ids)).alphabetically
  end

  def auto_categorize_transactions_later(transactions)
    AutoCategorizeJob.perform_later(self, transaction_ids: transactions.pluck(:id))
  end

  def auto_categorize_transactions(transaction_ids)
    AutoCategorizer.new(self, transaction_ids: transaction_ids).auto_categorize
  end

  def auto_detect_transaction_merchants_later(transactions)
    AutoDetectMerchantsJob.perform_later(self, transaction_ids: transactions.pluck(:id))
  end

  def auto_detect_transaction_merchants(transaction_ids)
    AutoMerchantDetector.new(self, transaction_ids: transaction_ids).auto_detect
  end

  def balance_sheet
    @balance_sheet ||= BalanceSheet.new(self)
  end

  def income_statement
    @income_statement ||= IncomeStatement.new(self)
  end

  def eu?
    country != "US" && country != "CA"
  end

  def requires_securities_data_provider?
    # If family has any trades, they need a provider for historical prices
    trades.any?
  end

  def requires_exchange_rates_data_provider?
    # If family has any accounts not denominated in the family's currency, they need a provider for historical exchange rates
    return true if accounts.where.not(currency: self.currency).any?

    # If family has any entries in different currencies, they need a provider for historical exchange rates
    uniq_currencies = entries.pluck(:currency).uniq
    return true if uniq_currencies.count > 1
    return true if uniq_currencies.count > 0 && uniq_currencies.first != self.currency

    false
  end

  def missing_data_provider?
    (requires_securities_data_provider? && Security.provider.nil?) ||
    (requires_exchange_rates_data_provider? && ExchangeRate.provider.nil?)
  end

  def oldest_entry_date
    entries.order(:date).first&.date || Date.current
  end

  # Used for invalidating family / balance sheet related aggregation queries
  def build_cache_key(key, invalidate_on_data_updates: false)
    # Our data sync process updates this timestamp whenever any family account successfully completes a data update.
    # By including it in the cache key, we can expire caches every time family account data changes.
    data_invalidation_key = invalidate_on_data_updates ? latest_sync_completed_at : nil

    # Also include the most recent balance update time across the family's accounts.
    # This ensures charts invalidate immediately when balances are materialized/backfilled,
    # not only when a sync completes or an account record changes.
    balances_max_updated_at = Balance
      .where(account_id: accounts.select(:id))
      .maximum(:updated_at)

    [
      id,
      key,
      data_invalidation_key,
      accounts.maximum(:updated_at),
      balances_max_updated_at
    ].compact.join("_")
  end

  # Latest update timestamp across all balances in this family, memoized per request.
  def balances_max_updated_at
    @balances_max_updated_at ||= Balance
      .where(account_id: accounts.select(:id))
      .maximum(:updated_at)
  end

  # Used for invalidating entry related aggregation queries
  def entries_cache_version
    @entries_cache_version ||= begin
      ts = entries.maximum(:updated_at)
      ts.present? ? ts.to_i : 0
    end
  end

  def self_hoster?
    Rails.application.config.app_mode.self_hosted?
  end
end
