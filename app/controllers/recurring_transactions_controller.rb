class RecurringTransactionsController < ApplicationController
  def index
    @recurring_view = params[:kind].presence_in(%w[transfers ignored]) || "detected"
    recurring_transactions = Current.family.recurring_transactions.includes(:merchant, :account, :destination_account)

    recurring_scope =
      case @recurring_view
      when "transfers"
        recurring_transactions.visible.where.not(destination_account_id: nil)
      when "ignored"
        recurring_transactions.where(status: "ignored")
      else
        recurring_transactions.visible.where(destination_account_id: nil)
      end.order(status: :asc, next_expected_date: :asc)
    @pagy, @recurring_transactions = pagy(:offset, recurring_scope, limit: 25)
    @assessments = @recurring_transactions.index_with(&:recurring_assessment)
    @transfer_destinations = Current.family.accounts.order(:name) if @recurring_view == "detected"
  end

  def identify
    count = RecurringTransaction.identify_patterns_for(Current.family)

    respond_to do |format|
      format.html do
        flash[:notice] = t("recurring_transactions.identified", count: count)
        redirect_to recurring_transactions_path
      end
    end
  end

  def cleanup
    count = RecurringTransaction.cleanup_stale_for(Current.family)

    respond_to do |format|
      format.html do
        flash[:notice] = t("recurring_transactions.cleaned_up", count: count)
        redirect_to recurring_transactions_path
      end
    end
  end

  def toggle_status
    @recurring_transaction = Current.family.recurring_transactions.visible.find(params[:id])

    if @recurring_transaction.active?
      @recurring_transaction.mark_inactive!
      message = t("recurring_transactions.marked_inactive")
    else
      @recurring_transaction.mark_active!
      message = t("recurring_transactions.marked_active")
    end

    respond_to do |format|
      format.html do
        flash[:notice] = message
        redirect_to recurring_transactions_path(kind: params[:kind])
      end
    end
  end

  def create_subscription
    @recurring_transaction = Current.family.recurring_transactions.visible.find(params[:id])
    subscription_plan = @recurring_transaction.create_subscription_plan!

    flash[:notice] = "Subscription plan created from recurring transaction."
    redirect_to subscription_plan_path(subscription_plan)
  rescue ActiveRecord::RecordInvalid, ArgumentError => e
    Rails.logger.warn("Failed to create subscription from recurring transaction #{params[:id]}: #{e.message}")
    flash[:alert] = e.message
    redirect_to recurring_transactions_path
  end

  def destroy
    @recurring_transaction = Current.family.recurring_transactions.visible.find(params[:id])
    @recurring_transaction.ignore!

    flash[:notice] = t("recurring_transactions.deleted")
    redirect_to recurring_transactions_path(kind: params[:kind])
  end

  def restore
    @recurring_transaction = Current.family.recurring_transactions.ignored.find(params[:id])
    @recurring_transaction.restore!

    flash[:notice] = "Recurring transaction restored and eligible for future detection."
    redirect_to recurring_transactions_path(kind: "ignored")
  end

  def confirm
    recurring_transaction = Current.family.recurring_transactions.visible.find(params[:id])
    recurring_transaction.confirm_as_recurring!

    flash[:notice] = "Recurring pattern confirmed."
    redirect_to recurring_transactions_path
  end

  def mark_transfer
    recurring_transaction = Current.family.recurring_transactions.visible.find(params[:id])
    destination_account = Current.family.accounts.find(params.require(:destination_account_id))
    recurring_transaction.mark_as_transfer!(destination_account)

    flash[:notice] = "Recurring pattern classified as a transfer."
    redirect_to recurring_transactions_path(kind: "transfers")
  rescue ArgumentError => error
    flash[:alert] = error.message
    redirect_to recurring_transactions_path
  end
end
