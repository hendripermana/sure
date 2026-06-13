class AccountReconciliationsController < ApplicationController
  before_action :set_account

  # GET /accounts/:account_id/reconciliation/new
  # Shows the reconciliation modal with current balance + input field
  def new
    @current_balance = @account.balance
    @last_entry_date = @account.entries.maximum(:date) || Date.current
    @days_since_last_entry = (@last_entry_date ? (Date.current - @last_entry_date).to_i : nil)
  end

  # POST /accounts/:account_id/reconciliation
  # Compares real balance vs app balance and shows diagnosis
  def create
    @real_balance = reconciliation_params[:real_balance].to_d
    @reconciliation_date = reconciliation_params[:date].present? ? Date.parse(reconciliation_params[:date]) : Date.current
    @current_balance = @account.balance.to_d
    @difference = @current_balance - @real_balance

    # Monthly transaction sums for pinpointing discrepancy month
    all_txs = @account.entries.excluding_split_parents.where(entryable_type: "Transaction").to_a
    @monthly_sums = Hash.new { |h, k| h[k] = { inflows: 0, outflows: 0 } }
    all_txs.each do |e|
      month = e.date.strftime("%Y-%m")
      if e.amount.to_f > 0
        @monthly_sums[month][:outflows] += e.amount.to_f.abs
      else
        @monthly_sums[month][:inflows] += e.amount.to_f.abs
      end
    end
    @monthly_sums = @monthly_sums.sort_by { |k, _| k }.reverse

    # Check if the balance is already in sync
    @is_synced = @difference.abs < 0.01

    if reconciliation_params[:apply] == "true" && !@is_synced
      # Apply the reconciliation using the existing ReconciliationManager
      result = @account.create_reconciliation(
        balance: @real_balance,
        date: @reconciliation_date
      )

      if result.success?
        redirect_to account_path(@account), notice: "Balance reconciled to #{format_currency(@real_balance)}. All balances recalculated."
        return
      else
        @error_message = result.error_message
      end
    end

    render :create
  end

  private

    def set_account
      @account = Current.family.accounts.find(params[:account_id])
    end

    def reconciliation_params
      params.require(:reconciliation).permit(:real_balance, :date, :apply)
    end

    def format_currency(amount)
      Money.new(amount, @account.currency).format
    end
end
