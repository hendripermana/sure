# Bridge ActiveSupport notifications to Sentry custom spans.
if defined?(Sentry)
  ActiveSupport::Notifications.subscribe("Sure.loan.installment.posted") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    payload = event.payload || {}
    Sentry.with_child_span(op: "loan.installment.posted", description: "Loan #{payload[:loan_id]}") do |span|
      begin
        span.set_data(:loan_id, payload[:loan_id])
        span.set_data(:installment_no, payload[:installment_no])
        span.set_data(:idempotent, payload[:idempotent])
      rescue NoMethodError
        # Ignore if set_data not available
      end
    end
  end

  [
    [ "Sure.loan.schedule.generate", "loan.schedule.generate", %i[loan_id principal tenor_months rate_or_profit ms] ],
    [ "Sure.loan.plan.regenerate", "loan.plan.regenerate", %i[loan_id replaced_count ms] ],
    [ "Sure.loan.extra_payment.applied", "loan.extra_payment.applied", %i[loan_id amount mode ms] ]
  ].each do |event_name, op, keys|
    ActiveSupport::Notifications.subscribe(event_name) do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      payload = event.payload || {}
      Sentry.with_child_span(op: op, description: ("Loan #{payload[:loan_id]}" if payload[:loan_id])) do |span|
        keys.each do |k|
          begin
            span.set_data(k, payload[k])
          rescue NoMethodError
          end
        end
      end
    end
  end
end
