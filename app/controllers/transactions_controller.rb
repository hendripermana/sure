class TransactionsController < ApplicationController
  include EntryableResource

  before_action :store_params!, only: :index

  def new
    super

    if params[:subscription_plan_id].present?
      @subscription_plan = Current.family.subscription_plans
                                      .includes(:account, :merchant, :service)
                                      .find_by(id: params[:subscription_plan_id])

      prefill_entry_from_subscription(@subscription_plan) if @subscription_plan
    end

    @income_categories = Current.family.categories.incomes.alphabetically
    @expense_categories = Current.family.categories.expenses.alphabetically
  end

  def index
    @q = search_params
    @search = Transaction::Search.new(Current.family, filters: @q)

    # PERFORMANCE: Eager load all associations to prevent N+1 queries
    base_scope = @search.transactions_scope
                       .reverse_chronological
                       .includes(
                         { entry: :account },
                         :category, :merchant, :tags,
                         :transfer_as_inflow, :transfer_as_outflow
                       )
                       .references(:entries, :accounts) # Force join for better performance

    @pagy, @transactions = pagy(:offset, base_scope, limit: per_page)

    # Preload split parent data
    entry_ids = @transactions.map { |t| t.entry.id }

    # Load split parent entries for grouped display
    @split_parents = if Current.user.show_split_grouped?
      split_parent_ids = @transactions.filter_map { |t| t.entry.parent_entry_id }.uniq
      if split_parent_ids.any?
        Entry.where(id: split_parent_ids)
             .includes(:account, entryable: [ :category, :merchant ])
             .index_by(&:id)
      else
        {}
      end
    else
      {}
    end

    # Preload which entries on this page are split parents (have children) to avoid N+1
    @split_parent_entry_ids = if entry_ids.any?
      Entry.where(parent_entry_id: entry_ids).distinct.pluck(:parent_entry_id).to_set
    else
      Set.new
    end
  end

  def clear_filter
    updated_params = {
      "q" => search_params,
      "page" => params[:page],
      "per_page" => params[:per_page]
    }

    q_params = updated_params["q"] || {}

    param_key = params[:param_key]
    param_value = params[:param_value]

    if q_params[param_key].is_a?(Array)
      q_params[param_key].delete(param_value)
      q_params.delete(param_key) if q_params[param_key].empty?
    else
      q_params.delete(param_key)
    end

    updated_params["q"] = q_params.presence

    # Add flag to indicate filters were explicitly cleared
    updated_params["filter_cleared"] = "1" if updated_params["q"].blank?

    Current.session.update!(prev_transaction_page_params: updated_params)

    redirect_to transactions_path(updated_params)
  end

  def create
    account = Current.family.accounts.find(params.dig(:entry, :account_id))

    # Extract splits from entry params so we don't pass it to the new entry initializer
    params_for_entry = entry_params
    splits_params = params_for_entry.delete(:splits)

    @entry = account.entries.new(params_for_entry)

    is_split = params[:split_transaction] == "1" && splits_params.present?

    if is_split
      raw_splits = splits_params
      raw_splits = raw_splits.values if raw_splits.respond_to?(:values)

      # Inflow (income) is stored as negative in DB, outflow (expense) is positive.
      # Splits are entered as positive values in the form, so we adjust based on nature.
      multiplier = @entry.amount.negative? ? -1 : 1

      normalized_splits = raw_splits.map do |s|
        {
          name: s[:name],
          amount: s[:amount].to_d * multiplier,
          category_id: s[:category_id].presence,
          excluded: s[:excluded]
        }
      end

      # Clear parent category since it's split
      if @entry.entryable.is_a?(Transaction)
        @entry.entryable.category_id = nil
      end
    end

    success = false
    Entry.transaction do
      if @entry.save
        if is_split
          begin
            @entry.split!(normalized_splits)
            success = true
          rescue ActiveRecord::RecordInvalid => e
            # Copy validation errors onto the parent entry to display in the UI
            e.record.errors.each do |error|
              @entry.errors.add(error.attribute, error.message)
            end
            raise ActiveRecord::Rollback
          end
        else
          success = true
        end
      else
        raise ActiveRecord::Rollback
      end
    end

    if success
      # OPTIMISTIC UPDATE: Immediate balance update for smooth UI experience
      # This prevents delay while waiting for async sync job
      entry_amount = @entry.amount
      entry_date = @entry.date
      entry_currency = @entry.currency

      # Only do optimistic update if:
      # 1. Entry is in account's native currency (avoid complex conversion)
      # 2. Entry is recent (within last 30 days) for safety
      # 3. Account has balances (avoid edge cases with new accounts)
      if entry_currency == account.currency &&
         entry_date >= 30.days.ago.to_date &&
         account.balances.any? &&
         !account.precious_metal?

        # CORRECT OPTIMISTIC BALANCE CALCULATION
        # Entry amount convention (from Balance::ForwardCalculator):
        #   - Negative amount = income (increases asset value, decreases liability)
        #   - Positive amount = expense (decreases asset value, increases liability)
        #
        # Balance::ForwardCalculator.signed_entry_flows does:
        #   account.asset? ? -entry_flows : entry_flows
        #
        # For ASSET accounts (checking, savings):
        #   - Expense (+100): signed_flows = -100 → balance DECREASES by 100 ✓
        #   - Income (-200): signed_flows = -(-200) = +200 → balance INCREASES by 200 ✓
        # For LIABILITY accounts (credit card, loan):
        #   - Expense (+100): signed_flows = +100 → balance INCREASES by 100 (more debt) ✓
        #   - Payment (-200): signed_flows = -200 → balance DECREASES by 200 (less debt) ✓
        flows_factor = account.asset? ? 1 : -1
        balance_change = -entry_amount * flows_factor  # CRITICAL: Must negate entry_amount!
        new_balance = account.balance + balance_change

        Rails.logger.info(
          "[Optimistic Update] Account #{account.id} (#{account.classification}): " \
          "balance #{account.balance} + (#{entry_amount} * #{flows_factor}) = #{new_balance}"
        )

        # Update account balance immediately (optimistic update)
        # ARCHITECTURE: Only update Account.balance (simple column)
        # Do NOT update Balance records - they have PostgreSQL generated columns
        # (end_balance, end_cash_balance, etc.) that are auto-calculated from flows
        # The async sync job will properly recalculate Balance records with detailed flows
        account.update_columns(
          balance: new_balance,
          updated_at: Time.current
        )

        # Broadcast immediate update to UI via Turbo
        account.broadcast_replace_to(
          account.family,
          target: "account_#{account.id}",
          partial: "accounts/account",
          locals: { account: account.reload }
        )
      end

      # Trigger debounced sync for accurate recalculation
      # Debouncing prevents sync flooding when creating multiple transactions
      @entry.sync_account_later

      @entry.lock_saved_attributes!
      @entry.transaction.lock_attr!(:tag_ids) if @entry.transaction.tags.any?

      flash[:notice] = "Transaction created"
      link_subscription_payment(@entry)

      redirect_target = if request.referer.present? && request.referer.include?("/accounts/")
        request.referer
      else
        transactions_path
      end

      respond_to do |format|
        format.html do
          redirect_to redirect_target
        end

        # TURBO STREAM: Close modal + redirect (keeps optimistic balance)
        # The optimistic update already changed the balance, redirect shows correct value
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("modal", ""),
            build_stream_redirect_to(redirect_target),
            *flash_notification_stream_items
          ]
        end
      end
    else
      # Re-render form with errors (stays in modal)
      @income_categories = Current.family.categories.incomes.alphabetically
      @expense_categories = Current.family.categories.expenses.alphabetically
      render :new, status: :unprocessable_entity
    end
  end

  def update
    # PERFORMANCE: Store old values before update for optimistic balance calculation
    old_amount = @entry.amount
    old_date = @entry.date
    old_currency = @entry.currency
    old_account = @entry.account

    if @entry.update(entry_params)
      transaction = @entry.transaction

      if needs_rule_notification?(transaction)
        flash[:cta] = {
          type: "category_rule",
          category_id: transaction.category_id,
          category_name: transaction.category.name
        }
      end

      # OPTIMISTIC UPDATE: Calculate balance delta for edited transaction
      # This handles changes to amount, date, currency, and even account changes
      new_amount = @entry.amount
      new_date = @entry.date
      new_currency = @entry.currency
      new_account = @entry.account

      # Only do optimistic update if transaction stayed in same currency and same account
      # More complex scenarios (currency change, account change) handled by async sync
      if old_currency == new_currency &&
         old_account.id == new_account.id &&
         new_currency == new_account.currency &&
         new_date >= 30.days.ago.to_date &&
         new_account.balances.any? &&
         !new_account.precious_metal?

        # Calculate DELTA between old and new amounts
        # For editing, we need to:
        # 1. Remove effect of old amount
        # 2. Add effect of new amount
        # CRITICAL: Match Balance::ForwardCalculator.signed_entry_flows convention
        #   account.asset? ? -entry_flows : entry_flows
        flows_factor = new_account.asset? ? 1 : -1

        # CRITICAL: Must negate entry_amount to match Balance calculator
        old_balance_change = -old_amount * flows_factor
        new_balance_change = -new_amount * flows_factor
        balance_delta = new_balance_change - old_balance_change

        optimistic_balance = new_account.balance + balance_delta

        Rails.logger.info(
          "[Optimistic Update - Edit] Account #{new_account.id} (#{new_account.classification}): " \
          "old_amount=#{old_amount}, new_amount=#{new_amount}, " \
          "balance #{new_account.balance} + delta(#{balance_delta}) = #{optimistic_balance}"
        )

        # Update account balance immediately (optimistic update)
        # ARCHITECTURE: Only update Account.balance (simple column)
        # Do NOT update Balance records - they have PostgreSQL generated columns
        new_account.update_columns(
          balance: optimistic_balance,
          updated_at: Time.current
        )

        # Broadcast immediate update to UI
        new_account.broadcast_replace_to(
          new_account.family,
          target: "account_#{new_account.id}",
          partial: "accounts/account",
          locals: { account: new_account.reload }
        )
      end

      @entry.sync_account_later
      @entry.lock_saved_attributes!
      @entry.transaction.lock_attr!(:tag_ids) if @entry.transaction.tags.any?

      respond_to do |format|
        format.html { redirect_back_or_to account_path(@entry.account), notice: "Transaction updated" }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              dom_id(@entry, :header),
              partial: "transactions/header",
              locals: { entry: @entry }
            ),
            turbo_stream.replace(@entry),
            *flash_notification_stream_items
          ]
        end
      end
    else
      render :show, status: :unprocessable_entity
    end
  end

  def merge_duplicate
    transaction = Current.family.transactions.includes(entry: :account).find(params[:id])

    if transaction.merge_with_duplicate!
      flash[:notice] = "Pending transaction merged"
    else
      flash[:alert] = "Could not merge duplicate transaction"
    end

    redirect_to transactions_path
  rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::RecordInvalid => e
    Rails.logger.error("Failed to merge duplicate transaction #{params[:id]}: #{e.message}")
    flash[:alert] = "Could not merge duplicate transaction"
    redirect_to transactions_path
  end

  def dismiss_duplicate
    transaction = Current.family.transactions.includes(entry: :account).find(params[:id])

    if transaction.dismiss_duplicate_suggestion!
      flash[:notice] = "Duplicate suggestion dismissed"
    else
      flash[:alert] = "Could not dismiss duplicate suggestion"
    end

    redirect_back_or_to transactions_path
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Failed to dismiss duplicate suggestion for transaction #{params[:id]}: #{e.message}")
    flash[:alert] = "Could not dismiss duplicate suggestion"
    redirect_back_or_to transactions_path
  end

  def mark_as_recurring
    transaction = Current.family.transactions.includes(entry: :account).find(params[:id])

    # Check if a recurring transaction already exists for this pattern
    existing = Current.family.recurring_transactions.find_by(
      merchant_id: transaction.merchant_id,
      name: transaction.merchant_id.present? ? nil : transaction.entry.name,
      currency: transaction.entry.currency,
      manual: true
    )

    if existing
      flash[:alert] = t("recurring_transactions.already_exists")
      redirect_back_or_to transactions_path
      return
    end

    begin
      recurring_transaction = RecurringTransaction.create_from_transaction(transaction)

      respond_to do |format|
        format.html do
          flash[:notice] = t("recurring_transactions.marked_as_recurring")
          redirect_back_or_to transactions_path
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      respond_to do |format|
        format.html do
          flash[:alert] = t("recurring_transactions.creation_failed")
          redirect_back_or_to transactions_path
        end
      end
    rescue StandardError => e
      respond_to do |format|
        format.html do
          flash[:alert] = t("recurring_transactions.unexpected_error")
          redirect_back_or_to transactions_path
        end
      end
    end
  end

  private
    def per_page
      params[:per_page].to_i.positive? ? params[:per_page].to_i : 20
    end

    def prefill_entry_from_subscription(subscription_plan)
      return unless subscription_plan

      @entry.account ||= subscription_plan.account
      @entry.currency ||= subscription_plan.currency
      @entry.amount ||= subscription_plan.amount

      # Prefer subscription's next billing date when available so the
      # manual payment aligns with the expected charge date.
      if subscription_plan.next_billing_at.present?
        @entry.date ||= subscription_plan.next_billing_at
      end

      transaction = @entry.entryable
      if transaction.present? && transaction.is_a?(Transaction)
        service_merchant = subscription_plan.service_merchant
        transaction.merchant ||= service_merchant if service_merchant.is_a?(Merchant)
      end
    end

    def needs_rule_notification?(transaction)
      return false if Current.user.rule_prompts_disabled

      if Current.user.rule_prompt_dismissed_at.present?
        time_since_last_rule_prompt = Time.current - Current.user.rule_prompt_dismissed_at
        return false if time_since_last_rule_prompt < 1.day
      end

      transaction.saved_change_to_category_id? && transaction.category_id.present? &&
      transaction.eligible_for_category_rule?
    end

    # When a transaction is created from the Subscription Manager, link it
    # back to the corresponding SubscriptionPlan and advance the billing
    # schedule when appropriate. This keeps subscription renewals in sync
    # with real-world manual payments without introducing tight coupling.
    def link_subscription_payment(entry)
      subscription_plan_id = params[:subscription_plan_id]
      return unless subscription_plan_id.present?

      subscription = Current.family.subscription_plans.find_by(id: subscription_plan_id)
      return unless subscription

      # Only treat outflows, matching currency, account, and a similar amount
      # as valid subscription payments.
      return unless entry.amount.positive?
      return unless entry.currency == subscription.currency
      return unless subscription.account_id == entry.account_id

      # Require the payment amount to be reasonably close to the
      # subscription amount so that unrelated expenses do not
      # accidentally advance the billing schedule. We accept payments
      # within ~10% of the configured subscription amount.
      amount_tolerance = subscription.amount / 10
      difference = (entry.amount - subscription.amount).abs
      return unless difference <= amount_tolerance

      billing_advanced = subscription.record_manual_payment!(paid_at: entry.date)
      if billing_advanced
        flash[:notice] = "Transaction created. #{subscription.name} billing advanced to #{subscription.next_billing_at.strftime('%b %d, %Y')}."
      end
    rescue StandardError => e
      Rails.logger.warn(
        "[SubscriptionPaymentLink] Failed to link entry #{entry.id} " \
        "to subscription #{subscription_plan_id}: #{e.class}: #{e.message}"
      )
    end

    def entry_params
      entry_params = params.require(:entry).permit(
        :name, :date, :amount, :currency, :excluded, :notes, :nature, :entryable_type, :receipt,
        entryable_attributes: [ :id, :category_id, :merchant_id, :kind, { tag_ids: [] } ],
        splits: [ :name, :amount, :category_id, :excluded ]
      )

      nature = entry_params.delete(:nature)

      if nature.present? && entry_params[:amount].present?
        signed_amount = nature == "inflow" ? -entry_params[:amount].to_d : entry_params[:amount].to_d
        entry_params = entry_params.merge(amount: signed_amount)
      end

      entry_params
    end

    def search_params
      cleaned_params = params.fetch(:q, {})
              .permit(
                :start_date, :end_date, :search, :amount,
                :amount_operator, :active_accounts_only,
                accounts: [], account_ids: [],
                categories: [], merchants: [], types: [], tags: [], status: []
              )
              .to_h
              .compact_blank

      cleaned_params.delete(:amount_operator) unless cleaned_params[:amount].present?


      cleaned_params
    end

    def store_params!
      if should_restore_params?
        params_to_restore = {}

        params_to_restore[:q] = stored_params["q"].presence || {}
        params_to_restore[:page] = stored_params["page"].presence || 1
        params_to_restore[:per_page] = stored_params["per_page"].presence || 50

        redirect_to transactions_path(params_to_restore)
      else
        Current.session.update!(
          prev_transaction_page_params: {
            q: search_params,
            page: params[:page],
            per_page: params[:per_page]
          }
        )
      end
    end

    def should_restore_params?
      request.query_parameters.blank? && (stored_params["q"].present? || stored_params["page"].present? || stored_params["per_page"].present?)
    end

    def stored_params
      Current.session.prev_transaction_page_params
    end
end
