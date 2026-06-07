class ReconcileTransactionJob < ApplicationJob
  queue_as :medium_priority

  discard_on ActiveRecord::RecordNotFound

  def perform(entry_id)
    entry = Entry.includes(:account, :entryable).find(entry_id)
    return unless entry.entryable_type == "Transaction"
    return if SubscriptionRenewal.where(entry_id: entry.id).exists?

    results = Recurring::Reconciler.new(
      entry.account.family,
      as_of: entry.date,
      entry: entry
    ).reconcile!
    Recurring::Notifier.new(entry.account.family, as_of: entry.date).deliver! if results.any?
  end
end
