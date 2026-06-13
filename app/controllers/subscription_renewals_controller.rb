class SubscriptionRenewalsController < ApplicationController
  include StreamExtensions
  include Notifiable
  include ActionView::RecordIdentifier

  before_action :set_subscription_plan
  before_action :ensure_payable_subscription, only: %i[new create]
  before_action :set_renewal, only: [ :show ]

  def index
    @renewals = @subscription_plan.subscription_renewals.reverse_chronological
    respond_to do |format|
      format.html { render plain: "Renewals for #{@subscription_plan.name}" }
      format.json { render json: @renewals }
    end
  end

  def new
    @renewal_form = SubscriptionPlan::RenewalForm.new(
      subscription_plan: @subscription_plan,
      account_id: @subscription_plan.account_id,
      actual_amount: @subscription_plan.amount,
      admin_fee: @subscription_plan.default_admin_fee || 0,
      paid_at: Date.current,
      currency: @subscription_plan.currency
    )
    @renewal_form.category_id = @renewal_form.default_category_id
    @accounts = Current.family.accounts
    @categories = Current.family.categories.where(classification: "expense").order(:name)
  end

  def create
    @renewal_form = SubscriptionPlan::RenewalForm.new(form_params.merge(subscription_plan: @subscription_plan, currency: @subscription_plan.currency))
    renewal = @renewal_form.create

    if renewal
      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = "Payment recorded successfully!"
          render turbo_stream: [
            turbo_stream.update("modal", ""),
            Array(flash_notification_stream_items),
            turbo_stream.replace(
              dom_id(@subscription_plan, :row),
              partial: "subscription_plans/row",
              locals: { subscription: @subscription_plan }
            )
          ].flatten
        end
        format.html { redirect_to subscription_plans_path, notice: "Payment recorded successfully!" }
      end
    else
      @accounts = Current.family.accounts
      @categories = Current.family.categories.where(classification: "expense").order(:name)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("modal", template: "subscription_renewals/new", layout: false), status: :unprocessable_entity
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def show
    respond_to do |format|
      format.html { render plain: "Renewal ##{@renewal.id}" }
      format.json { render json: @renewal }
    end
  end

  private

    def set_subscription_plan
      @subscription_plan = Current.family.subscription_plans.find(params[:subscription_plan_id])
    end

    def set_renewal
      @renewal = @subscription_plan.subscription_renewals.find(params[:id])
    end

    def ensure_payable_subscription
      return if @subscription_plan.active_or_trial?

      redirect_to subscription_plan_path(@subscription_plan),
        alert: "Payments can only be recorded for active or trial subscriptions."
    end

    def form_params
      raw_params = params.require(:subscription_plan_renewal_form)
      permitted = raw_params.permit(
        :actual_amount,
        :admin_fee,
        :paid_at,
        :payment_method,
        :notes,
        :update_default_account
      )

      if raw_params.key?(:account_id)
        permitted[:account_id] =
          @subscription_plan.family.accounts.where(id: raw_params[:account_id]).pick(:id) ||
          raw_params[:account_id]
      end

      if raw_params.key?(:category_id)
        permitted[:category_id] =
          @subscription_plan.family.categories.where(id: raw_params[:category_id]).pick(:id) ||
          raw_params[:category_id]
      end

      permitted
    end
end
