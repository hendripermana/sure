# frozen_string_literal: true

require "test_helper"

# Regression guard for the order-dependent flakiness fixed in issue 003.
#
# turbo-rails only requires and mixes Turbo::Broadcastable::TestHelper into
# ActiveSupport::TestCase from inside an `on_load(:action_cable)` hook. Because
# ActionCable loads lazily, parallel workers that ran a Turbo-broadcast test
# before ActionCable was loaded raised `NoMethodError: undefined method
# 'capture_turbo_stream_broadcasts'`. test_helper now touches
# ActionCable::Server::Base so the hook fires in the parent process before
# workers fork. This test fails loudly if that wiring is removed.
class TurboBroadcastHelperAvailabilityTest < ActiveSupport::TestCase
  test "capture_turbo_stream_broadcasts is available to every test case" do
    assert defined?(Turbo::Broadcastable::TestHelper),
      "ActionCable must be loaded so turbo-rails defines its broadcast test helper"

    assert_includes ActiveSupport::TestCase.ancestors, Turbo::Broadcastable::TestHelper,
      "Turbo::Broadcastable::TestHelper must be mixed into ActiveSupport::TestCase " \
      "so capture_turbo_stream_broadcasts is available in every parallel worker"

    assert_respond_to self, :capture_turbo_stream_broadcasts
  end
end
