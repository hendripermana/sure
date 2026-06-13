require "test_helper"

class TransactionTest < ActiveSupport::TestCase
  include EntriesTestHelper

  test "transfer classification covers every transfer kind" do
    Transaction::TRANSFER_KINDS.each do |kind|
      assert Transaction.new(kind: kind).transfer?, "Expected #{kind} to be classified as a transfer"
    end

    assert_not Transaction.new(kind: "standard").transfer?
  end
end
