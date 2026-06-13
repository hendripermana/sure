class SubscriptionPlansController < ApplicationController
  include ActionView::RecordIdentifier
  include Notifiable

  before_action :authenticate_user!
  before_action :set_subscription_plan, only: %i[show edit update destroy pause resume cancel undo_cancellation]
  before_action :authorize_family_access, only: %i[show edit update destroy pause resume cancel undo_cancellation]

  # GET /subscription_plans
  def index
    @subscription_plans = Current.family.subscription_plans
      .includes(:service, :merchant, :account)
      .unarchived
      .order(:name)

    # Dashboard data
    @active_subscriptions = @subscription_plans.active
    @paused_subscriptions = @subscription_plans.where(status: "paused")
    @cancelled_subscriptions = @subscription_plans.where(status: "cancelled")
    @upcoming_renewals = @subscription_plans.upcoming_renewals
    @overdue_subscriptions = @subscription_plans.overdue
    @trial_ending = @subscription_plans.trial_ending

    # Analytics
    @analytics = SubscriptionAnalytics.new(Current.family)

    respond_to do |format|
      format.html
      format.json { render json: safe_subscription_json(@subscription_plans) }
    end
  end

  # GET /subscription_plans/1
  def show
    @entries = Entry.where(id: @subscription_plan.subscription_renewals.where.not(entry_id: nil).pluck(:entry_id)).reverse_chronological
    @timeline_events = @subscription_plan.audit_logs.reverse_chronological.limit(30)
    respond_to do |format|
      format.html
      format.json { render json: safe_subscription_json(@subscription_plan) }
    end
  end

  # GET /subscription_plans/new
  def new
    @subscription_plan = Current.family.subscription_plans.new(
      currency: Current.family.currency,
      started_at: Date.current,
      next_billing_at: 1.month.from_now.to_date
    )
    load_form_options

    respond_to do |format|
      format.html
      format.json { render json: safe_subscription_json(@subscription_plan) }
    end
  end

  # POST /subscription_plans
  def create
    @subscription_plan = Current.family.subscription_plans.new(subscription_plan_params)

    respond_to do |format|
      if @subscription_plan.save
        track_subscription_created(@subscription_plan)
        format.html {
          redirect_to subscription_plans_path,
          notice: "Subscription plan created successfully!"
        }
        format.json { render json: safe_subscription_json(@subscription_plan), status: :created }
      else
        load_form_options
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @subscription_plan.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /subscription_plans/1/edit
  def edit
    load_form_options

    respond_to do |format|
      format.html
      format.json { render json: safe_subscription_json(@subscription_plan) }
    end
  end

  # PATCH/PUT /subscription_plans/1
  def update
    respond_to do |format|
      if @subscription_plan.update(subscription_plan_params)
        format.html {
          redirect_to subscription_plans_path,
          notice: "Subscription plan updated successfully!"
        }
        format.json { render json: safe_subscription_json(@subscription_plan) }
      else
        load_form_options
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @subscription_plan.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /subscription_plans/1
  def destroy
    @subscription_plan.archive!

    respond_to do |format|
      format.html {
        redirect_to subscription_plans_path,
        notice: "Subscription plan archived successfully!"
      }
      format.json { head :no_content }
    end
  end

  # PATCH /subscription_plans/1/pause
  def pause
    success = @subscription_plan.pause!

    respond_to do |format|
      format.html {
        redirect_to subscription_plans_path,
          flash: success ? { notice: "Subscription plan paused!" } : { alert: @subscription_plan.errors.full_messages.to_sentence }
      }
      format.json {
        if success
          render json: safe_subscription_json(@subscription_plan)
        else
          render json: { errors: @subscription_plan.errors.full_messages }, status: :unprocessable_entity
        end
      }
    end
  end

  # PATCH /subscription_plans/1/resume
  def resume
    success = @subscription_plan.resume!

    respond_to do |format|
      format.html {
        redirect_to subscription_plans_path,
          flash: success ? { notice: "Subscription plan resumed!" } : { alert: @subscription_plan.errors.full_messages.to_sentence }
      }
      format.json {
        if success
          render json: safe_subscription_json(@subscription_plan)
        else
          render json: { errors: @subscription_plan.errors.full_messages }, status: :unprocessable_entity
        end
      }
    end
  end

  # PATCH /subscription_plans/1/cancel
  def cancel
    at_next_renewal = params[:timing] == "period_end"
    success = @subscription_plan.cancel!(at_next_renewal: at_next_renewal)
    notice = at_next_renewal ? "Subscription will cancel at the next renewal." : "Subscription plan cancelled!"

    respond_to do |format|
      format.html {
        redirect_to subscription_plans_path,
          flash: success ? { notice: notice } : { alert: @subscription_plan.errors.full_messages.to_sentence }
      }
      format.json {
        if success
          render json: safe_subscription_json(@subscription_plan)
        else
          render json: { errors: @subscription_plan.errors.full_messages }, status: :unprocessable_entity
        end
      }
    end
  end

  def undo_cancellation
    success = @subscription_plan.undo_cancellation!

    respond_to do |format|
      format.html {
        redirect_to subscription_plans_path,
          flash: success ? { notice: "Scheduled cancellation removed." } : { alert: @subscription_plan.errors.full_messages.to_sentence }
      }
      format.json {
        if success
          render json: safe_subscription_json(@subscription_plan)
        else
          render json: { errors: @subscription_plan.errors.full_messages }, status: :unprocessable_entity
        end
      }
    end
  end


  # GET /subscription_plans/check_duplicate
  # Check if user already has a subscription for the given service
  def check_duplicate
    service_id = params[:service_id]
    exclude_id = params[:exclude_id]

    return render json: { duplicate: false } if service_id.blank?

    existing = Current.family.subscription_plans
      .unarchived
      .where(merchant_id: service_id)

    # Exclude current subscription when editing
    existing = existing.where.not(id: exclude_id) if exclude_id.present?

    if existing.exists?
      subscription = existing.first
      render json: {
        duplicate: true,
        message: "You already have a subscription for this service: \"#{subscription.name}\" (#{subscription.status})"
      }
    else
      render json: { duplicate: false }
    end
  end

  private

    def set_subscription_plan
      @subscription_plan = Current.family.subscription_plans.find(params[:id])
    end

    def authorize_family_access
      return if @subscription_plan.family == Current.family
      redirect_to root_path, alert: "Access denied"
    end

    def subscription_plan_params
      permitted = params.require(:subscription_plan).permit(
        :name, :description,
        :amount, :currency, :billing_cycle, :status,
        :interval_count, :interval_unit,
        :started_at, :trial_ends_at, :next_billing_at,
        :auto_renew, :payment_method, :shared_within_family,
        :max_usage_allowed, :payment_notes
      )

      if params[:subscription_plan].key?(:account_id)
        account_id = safe_account_id(params[:subscription_plan][:account_id])
        permitted[:account_id] = account_id if account_id.present?
      end

      if params[:subscription_plan].key?(:merchant_id)
        merchant_id = safe_service_merchant_id(params[:subscription_plan][:merchant_id])
        permitted[:merchant_id] = merchant_id if merchant_id.present?
      end

      permitted
    end

    def safe_account_id(account_id)
      return if account_id.blank?

      Current.family.accounts.where(id: account_id).pick(:id)
    end

    def safe_service_merchant_id(merchant_id)
      return if merchant_id.blank?

      ServiceMerchant.available_to(Current.family).where(id: merchant_id).pick(:id)
    end

    # Sanitize subscription data for JSON responses to prevent data exposure
    def safe_subscription_json(subscriptions)
      safe_attributes = %i[
        id name description amount currency billing_cycle status
        started_at trial_ends_at next_billing_at auto_renew
        payment_method shared_within_family created_at updated_at
      ]

      if subscriptions.respond_to?(:map)
        subscriptions.map { |sub| subscription_to_safe_hash(sub, safe_attributes) }
      else
        subscription_to_safe_hash(subscriptions, safe_attributes)
      end
    end

    def subscription_to_safe_hash(subscription, safe_attributes)
      sm = subscription.service_merchant
      hash = subscription.as_json(only: safe_attributes)
      hash["service_name"] = sm&.name
      hash["service_category"] = sm.respond_to?(:subscription_category) ? sm.subscription_category : sm&.category
      hash["account_name"] = subscription.account&.name
      hash["days_until_renewal"] = subscription.days_until_renewal
      hash["monthly_equivalent_amount"] = subscription.monthly_equivalent_amount
      hash
    end

    def load_services
      ServiceMerchant.available_to(Current.family)
    end

    def load_form_options
      @services = load_services
      @service_schedule_defaults = @services.to_h { |service| [ service.id, service.billing_schedule.to_h ] }
      @accounts = Current.family.accounts
    end

    def track_subscription_created(subscription_plan)
      sm = subscription_plan.service_merchant

      # Analytics tracking
      if defined?(Ahoy)
        ahoy.track(
          "subscription_created",
          {
            subscription_id: subscription_plan.id,
            service: sm&.name,
            amount: subscription_plan.amount,
            billing_cycle: subscription_plan.billing_cycle,
            payment_method: subscription_plan.payment_method
          }
        )
      end

      # Sentry tracking for monitoring
      Sentry.capture_message(
        "Subscription created",
        level: :info,
        tags: {
          service: sm&.name,
          billing_cycle: subscription_plan.billing_cycle
        },
        extra: {
          family_id: Current.family.id,
          user_id: Current.user.id,
          amount: subscription_plan.amount
        }
      )
    end
end
