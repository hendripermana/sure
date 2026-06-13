require "test_helper"

class EntriesSplitGroupTest < ActionView::TestCase
  def setup
    @account = accounts(:depository)
    @parent_entry = entries(:transaction)
  end

  test "renders account transaction link with legacy tab parameter and stop propagation actions" do
    split_group = EntriesHelper::SplitGroup.new(parent: @parent_entry, children: [])

    render partial: "entries/split_group", locals: { split_group: split_group, view_ctx: "global" }

    assert_select "a.split-group__account-link" do |elements|
      assert_equal 2, elements.length  # Desktop and mobile versions

      # Check desktop link
      desktop_link = elements.first
      assert_equal account_path(@account, tab: "transactions"), desktop_link[:href]
      assert_match(/click->split-group#stop/, desktop_link["data-action"])
      assert_match(/keydown\.enter->split-group#stop/, desktop_link["data-action"])
      assert_match(/keydown\.space->split-group#stop/, desktop_link["data-action"])
      assert_equal "_top", desktop_link["data-turbo-frame"]

      # Check mobile link has same attributes
      mobile_link = elements.last
      assert_equal account_path(@account, tab: "transactions"), mobile_link[:href]
      assert_match(/click->split-group#stop/, mobile_link["data-action"])
    end
  end

  test "renders account name in link text" do
    split_group = EntriesHelper::SplitGroup.new(parent: @parent_entry, children: [])

    render partial: "entries/split_group", locals: { split_group: split_group, view_ctx: "global" }

    assert_select "a.split-group__account-link", text: @account.name
  end

  test "renders split badge with count" do
    split_group = EntriesHelper::SplitGroup.new(parent: @parent_entry, children: [])

    render partial: "entries/split_group", locals: { split_group: split_group, view_ctx: "global" }

    assert_select "span", text: /Split · 0/
  end
end
