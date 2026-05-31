module EntriesHelper
  SplitGroup = Data.define(:parent, :children)

  def group_split_entries(entries, split_parents)
    return entries if split_parents.blank?

    # Parent ids that have at least one child present in this list — these
    # parents are shown as the split-group header, so we must not also render
    # them as a standalone row (relevant on the account page where the parent
    # entry lives in the same list as its children).
    grouped_parent_ids = entries.select(&:split_child?)
                                .map(&:parent_entry_id)
                                .select { |pid| split_parents[pid] }
                                .to_set

    result = []
    seen_parent_ids = Set.new

    entries.each do |entry|
      if entry.split_child? && split_parents[entry.parent_entry_id]
        parent_id = entry.parent_entry_id
        next if seen_parent_ids.include?(parent_id)

        seen_parent_ids.add(parent_id)
        children = entries.select { |e| e.parent_entry_id == parent_id }
        result << SplitGroup.new(parent: split_parents[parent_id], children: children)
      elsif entry.split_parent? && grouped_parent_ids.include?(entry.id)
        next # rendered as the group header instead of a standalone row
      else
        result << entry
      end
    end

    result
  end

  def entries_by_date(entries, totals: false)
    transfer_groups = entries.group_by do |entry|
      # Only check for transfer if it's a transaction
      next nil unless entry.entryable_type == "Transaction"
      entry.entryable.transfer&.id
    end

    # For a more intuitive UX, we do not want to show the same transfer twice in the list
    deduped_entries = transfer_groups.flat_map do |transfer_id, grouped_entries|
      if transfer_id.nil? || grouped_entries.size == 1
        grouped_entries
      else
        grouped_entries.reject do |e|
          e.entryable_type == "Transaction" &&
          e.entryable.transfer_as_inflow.present?
        end
      end
    end

    blocks = deduped_entries
      .group_by(&:date)
      .sort
      .reverse_each
      .filter_map do |date, grouped_entries|
        content = capture { yield grouped_entries }
        next if content.blank?
        render(partial: "entries/entry_group", locals: { date:, entries: grouped_entries, content:, totals: }).to_s
      end

    safe_join(blocks)
  end

  def entry_name_detailed(entry)
    [
      entry.date,
      format_money(entry.amount_money),
      entry.account.name,
      entry.name
    ].join(" • ")
  end
end
