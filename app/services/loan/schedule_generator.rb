class Loan::ScheduleGenerator
  Row = Struct.new(:due_date, :principal, :interest, :total, keyword_init: true)

  def initialize(principal_amount:, rate_or_profit:, tenor_months:, payment_frequency: "MONTHLY", schedule_method: "ANNUITY", start_date: Date.current, balloon_amount: 0, loan_id: nil)
    @principal = principal_amount.to_d
    @annual_rate = rate_or_profit.to_d
    @tenor_months = tenor_months.to_i
    @frequency = (payment_frequency || "MONTHLY").upcase
    @method = (schedule_method || "ANNUITY").upcase
    @start_date = start_date.is_a?(Date) ? start_date : Date.parse(start_date.to_s)
    @balloon = balloon_amount.to_d
    @loan_id = loan_id
  end

  def generate
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    if principal.negative?
      log_error("negative_principal")
      raise ArgumentError, "Principal cannot be negative"
    end
    if balloon.negative? || balloon > principal
      log_error("invalid_balloon")
      raise ArgumentError, "Balloon must be between 0 and principal"
    end

    rows = nil
    if defined?(Sentry)
      Sentry.with_child_span(op: "loan.schedule.generate", description: ("Loan #{loan_id}" if loan_id)) do |span|
        begin
          span.set_data(:loan_id, loan_id) if loan_id
          span.set_data(:tenor_months, tenor_months)
          span.set_data(:rate_or_profit, annual_rate)
        rescue NoMethodError; end
        rows = build_rows
      end
    else
      rows = build_rows
    end
    rows
  ensure
    t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ms = ((t1 - t0) * 1000).round(1)
    begin
      ActiveSupport::Notifications.instrument(
        "sure.loan.schedule.generate",
        loan_id: loan_id,
        principal: principal.to_s,
        tenor_months: tenor_months,
        rate_or_profit: annual_rate.to_s,
        ms: ms
      )
    rescue StandardError
    end
    if defined?(Sentry)
      begin
        tx = Sentry.get_current_scope.get_transaction
        record_measurement(tx, "loan.schedule.ms", ms, "millisecond")
      rescue NoMethodError; end
    end
    Rails.logger.info({ at: "Loan::ScheduleGenerator.generate", ms: ms, principal: principal.to_s, rate: annual_rate.to_s, tenor: tenor_months, frequency: frequency, method: method }.to_json) rescue nil
  end

  private
    attr_reader :principal, :annual_rate, :tenor_months, :frequency, :method, :start_date, :balloon

    def periods
      count =
        case frequency
        when "WEEKLY" then (tenor_months * 52.0 / 12).round
        when "BIWEEKLY" then (tenor_months * 26.0 / 12).round
        else
          mi = months_interval
          mi = 1 if mi.nil? || mi <= 0
          (tenor_months.to_d / mi).to_i
        end

      if count <= 0
        raise ArgumentError, "Tenor months must be positive"
      end

      count
    end

    def period_rate
      case frequency
      when "WEEKLY" then (annual_rate / 52)
      when "BIWEEKLY" then (annual_rate / 26)
      else
        mi = months_interval
        per_year = (12.to_d / (mi.presence || 1)).to_d
        per_year = 12 if per_year <= 0
        (annual_rate / per_year)
      end
    end

    def next_due_date(i)
      case frequency
      when "WEEKLY" then start_date + (i * 7)
      when "BIWEEKLY" then start_date + (i * 14)
      else
        mi = months_interval
        mi = 1 if mi.nil? || mi <= 0
        start_date >> (i * mi)
      end
    end

    def months_interval
      cfg = LoanConfigurationService.payment_frequency_config(frequency)
      val = cfg && (cfg[:months_interval] || cfg["months_interval"])
      val ? BigDecimal(val.to_s) : 1.to_d
    end

    def annuity_payment
      r = period_rate
      n = periods
      p = amortizing_principal
      return (p / n) if r.zero?
      (p * r * (1 + r)**n) / ((1 + r)**n - 1)
    end

    def annuity_schedule
      bal = amortizing_principal
      pay = annuity_payment
      rows = []
      periods.times do |i|
        int = (bal * period_rate)
        princ = [ pay - int, bal ].min
        total = princ + int
        rows << Row.new(due_date: next_due_date(i + 1), principal: princ.round(4), interest: int.round(4), total: total.round(4))
        bal = (bal - princ).negative? ? 0.to_d : (bal - princ)
      end
      # Adjust rounding drift on principal to match original principal
      drift = amortizing_principal - rows.sum { |r| r.principal }
      if drift.nonzero?
        rows.last.principal = (rows.last.principal + drift).round(4)
        rows.last.total = (rows.last.principal + rows.last.interest).round(4)
      end
      # Add balloon to the last row if any
      if balloon.positive?
        rows.last.principal = (rows.last.principal + balloon).round(4)
        rows.last.total = (rows.last.total + balloon).round(4)
      end
      rows
    end

    def flat_schedule
      n = periods
      princ_per = (amortizing_principal / n)
      interest_per_period = principal * period_rate
      rows = []
      n.times do |i|
        princ = princ_per
        int = interest_per_period
        total = princ + int
        rows << Row.new(due_date: next_due_date(i + 1), principal: princ.round(4), interest: int.round(4), total: total.round(4))
      end
      # Adjust principal drift
      drift = amortizing_principal - rows.sum { |r| r.principal }
      if drift.nonzero?
        rows.last.principal = (rows.last.principal + drift).round(4)
        rows.last.total = (rows.last.principal + rows.last.interest).round(4)
      end
      if balloon.positive?
        rows.last.principal = (rows.last.principal + balloon).round(4)
        rows.last.total = (rows.last.total + balloon).round(4)
      end
      rows
    end

    def zero_rate_schedule
      amort = [ amortizing_principal, 0 ].max
      return [] if amort.zero? && balloon.zero?

      n = [ periods, 1 ].max
      princ_per = (amort / n)
      rows = []
      n.times do |i|
        rows << Row.new(due_date: next_due_date(i + 1), principal: princ_per.round(4), interest: 0.to_d, total: princ_per.round(4))
      end
      drift = amort - rows.sum { |r| r.principal }
      if drift.nonzero?
        rows.last.principal = (rows.last.principal + drift).round(4)
        rows.last.total = rows.last.principal
      end
      if balloon.positive?
        rows.last.principal = (rows.last.principal + balloon).round(4)
        rows.last.total = (rows.last.total + balloon).round(4)
      end
      rows
    end

    def bullet_schedule
      n = [ periods, 1 ].max
      r = period_rate
      rows = []
      n.times do |i|
        # Interest-only each period, full principal at maturity
        interest = (r.zero? ? 0.to_d : (principal * r))
        principal_component = (i == n - 1) ? principal : 0.to_d
        total = principal_component + interest
        rows << Row.new(
          due_date: next_due_date(i + 1),
          principal: principal_component.round(4),
          interest: interest.round(4),
          total: total.round(4)
        )
      end
      # Adjust drift on principal if any
      drift = principal - rows.sum { |r| r.principal }
      if drift.nonzero?
        rows.last.principal = (rows.last.principal + drift).round(4)
        rows.last.total = (rows.last.principal + rows.last.interest).round(4)
      end
      rows
    end

    def balloon_schedule
      n = [ periods, 1 ].max
      r = period_rate
      # Distribute (principal - balloon) across first (n - 1) periods, pay balloon at end
      rows = []
      if n == 1
        interest = (r.zero? ? 0.to_d : (principal * r))
        rows << Row.new(
          due_date: next_due_date(1),
          principal: principal.round(4),
          interest: interest.round(4),
          total: (principal + interest).round(4)
        )
        return rows
      end

      amort = amortizing_principal
      princ_per = (n - 1) > 0 ? (amort / (n - 1)) : amort
      remaining = principal

      n.times do |i|
        interest = (r.zero? ? 0.to_d : (remaining * r))
        if i == n - 1
          principal_component = remaining
        else
          principal_component = [ princ_per, [ remaining - balloon, 0.to_d ].max ].min
        end
        total = principal_component + interest
        rows << Row.new(
          due_date: next_due_date(i + 1),
          principal: principal_component.round(4),
          interest: interest.round(4),
          total: total.round(4)
        )
        remaining = (remaining - principal_component)
      end

      # Adjust drift so sum(principal) == principal
      drift = principal - rows.sum { |r| r.principal }
      if drift.nonzero?
        rows.last.principal = (rows.last.principal + drift).round(4)
        rows.last.total = (rows.last.principal + rows.last.interest).round(4)
      end

      rows
    end

    def amortizing_principal
      [ principal - balloon, 0.to_d ].max
    end

    def loan_id
      @loan_id
    end

    def build_rows
      if annual_rate.zero?
        # Zero rate special handling with balloon support
        case method
        when "BULLET" then bullet_schedule
        when "BALLOON" then balloon_schedule
        else
          zero_rate_schedule
        end
      else
        case method
        when "ANNUITY", "EFFECTIVE" then annuity_schedule
        when "FLAT" then flat_schedule
        when "BULLET" then bullet_schedule
        when "BALLOON" then balloon_schedule
        else annuity_schedule
        end
      end
    end

    def log_error(kind)
      Rails.logger.error({ at: "Loan::ScheduleGenerator.error", kind: kind, principal: principal.to_s, balloon: balloon.to_s, tenor: tenor_months, frequency: frequency, method: method }.to_json)
    rescue
      # no-op
    end

    def record_measurement(tx, name, value, unit)
      return unless tx

      callable = if tx.respond_to?(:set_measurement)
        method = tx.method(:set_measurement) rescue nil
        if method && (method.arity.zero? || method.arity == -1)
          handler = method.call rescue nil
          handler if handler.respond_to?(:call)
        else
          method
        end
      end

      callable&.call(name, value, unit)
    rescue StandardError
      nil
    end
end
