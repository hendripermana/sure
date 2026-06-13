require "test_helper"

class LoanPostInstallmentObservabilityTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @loan = accounts(:loan)
    @cash = accounts(:depository)
    LoanInstallment.create!(
      account_id: @loan.id,
      installment_no: 3,
      due_date: Date.current + 1,
      status: "planned",
      principal_amount: 1000,
      interest_amount: 0,
      total_amount: 1000
    )
  end
  test "fires notifications and Sentry spans when available" do
    events = []
    sub = ActiveSupport::Notifications.subscribe("sure.loan.installment.posted") { |*args| events << ActiveSupport::Notifications::Event.new(*args) }

    # Provide a minimal Sentry shim if not present and ensure the shim is API-compatible
    unless defined?(::Sentry)
      Object.const_set(:Sentry, Module.new)
    end

    ::Sentry.singleton_class.class_eval do
      attr_accessor :span_called unless method_defined?(:span_called)

      def with_child_span(*_args, **_kwargs)
        self.span_called = true
        span = __sure_test_span
        if block_given?
          yield span
        else
          span
        end
      end

      def add_breadcrumb(*); end

      def configure_scope(*_args, **_kwargs)
        scope = __sure_test_scope
        yield scope if block_given?
        scope
      end

      def get_current_scope(*_args, **_kwargs)
        scope = __sure_test_scope
        yield scope if block_given?
        scope
      end

      private

      def __sure_test_span
        Object.new.tap do |span|
          span.define_singleton_method(:set_data) { |*_args, **_kwargs| }
          span.define_singleton_method(:set_description) { |*_args, **_kwargs| }
          span.define_singleton_method(:set_http_status) { |*_args| }
        end
      end

      def __sure_test_scope
        tx = Object.new
        tx.define_singleton_method(:set_measurement) { |*_args| }

        Object.new.tap do |scope|
          scope.define_singleton_method(:set_transaction_name) { |*_args, **_kwargs| }
          scope.define_singleton_method(:set_tags) { |*_args, **_kwargs| }
          scope.define_singleton_method(:set_context) { |*_args, **_kwargs| }
          scope.define_singleton_method(:set_user) { |*_args, **_kwargs| }
          scope.define_singleton_method(:get_transaction) { tx }
        end
      end
    end

    ::Sentry.span_called = false
    result = Loan::PostInstallment.new(
      family: @family,
      account_id: @loan.id,
      source_account_id: @cash.id,
      date: Date.current
    ).call!

    assert result.success?
    assert events.any?, "expected instrumentation event"
    assert ::Sentry.respond_to?(:span_called) && ::Sentry.span_called, "expected Sentry span to be called"
  ensure
    ActiveSupport::Notifications.unsubscribe(sub) if sub
  end
end
