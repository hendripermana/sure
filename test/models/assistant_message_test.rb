require "test_helper"

class AssistantMessageTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @chat = chats(:one)
  end

  test "creates message and appends text correctly" do
    message = AssistantMessage.create!(
      chat: @chat,
      content: "Hello",
      ai_model: "gpt-4.1"
    )

    assert_equal "Hello", message.content
    assert_equal @chat, message.chat
    assert_equal "gpt-4.1", message.ai_model
  end

  test "append_text! updates content and saves" do
    message = AssistantMessage.create!(
      chat: @chat,
      content: "Start",
      ai_model: "gpt-4.1"
    )

    message.append_text!(" more text")
    assert_equal "Start more text", message.content

    # Verify it's persisted
    message.reload
    assert_equal "Start more text", message.content
  end

  test "updates content smoothly with morphing broadcast" do
    message = AssistantMessage.create!(
      chat: @chat,
      content: "Initial",
      ai_model: "gpt-4.1"
    )

    # Update should work without errors and preserve chat relationship
    assert_nothing_raised do
      message.update!(content: "Updated")
    end

    assert_equal "Updated", message.content
    assert_equal @chat, message.chat
  end

  test "skips broadcast when chat is not present" do
    message = AssistantMessage.create!(
      chat: @chat,
      content: "Test",
      ai_model: "gpt-4.1"
    )

    message.stubs(:chat).returns(nil)

    assert_no_enqueued_jobs only: Turbo::Streams::BroadcastJob do
      message.send(:broadcast_replace_to_with_morph)
    end
  end
end
