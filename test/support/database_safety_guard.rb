# frozen_string_literal: true

# Defense-in-depth guard ensuring the Minitest suite can never run against a
# production database, even when conflicting POSTGRES_DB / POSTGRES_DB_PRODUCTION
# shell variables resolve the test environment onto a production database name
# (issue 003, acceptance criterion #4).
#
# `verify!` holds the pure decision so it can be unit-tested without aborting the
# process. `enforce!` wraps it for `test_helper`, translating a violation into a
# hard `abort` before Rails' `maintain_test_schema!` can purge a real database.
module DatabaseSafetyGuard
  class UnsafeDatabaseError < StandardError; end

  module_function

  # Returns the configured database name when it is a safe test database,
  # otherwise raises UnsafeDatabaseError describing the violation.
  def verify!(rails_env:, configured_database:, production_database:)
    unless rails_env.to_s == "test"
      raise UnsafeDatabaseError,
        "Refusing to run the test suite outside the test environment " \
        "(RAILS_ENV=#{rails_env.inspect})."
    end

    configured = normalize(configured_database)

    if configured.empty?
      raise UnsafeDatabaseError,
        "Refusing to run the test suite: no test database is configured."
    end

    if configured == normalize(production_database)
      raise UnsafeDatabaseError,
        "Refusing to run the test suite against the production database " \
        "#{configured_database.to_s.strip.inspect}. Set POSTGRES_DB_TEST to a " \
        "dedicated test database that does not collide with POSTGRES_DB / " \
        "POSTGRES_DB_PRODUCTION."
    end

    configured_database.to_s.strip
  end

  # Verifies the live configuration and aborts the process on any violation so
  # no schema maintenance touches a production database.
  def enforce!(rails_env:, configured_database:, production_database:)
    verify!(
      rails_env: rails_env,
      configured_database: configured_database,
      production_database: production_database
    )
  rescue UnsafeDatabaseError => error
    abort("FATAL: #{error.message}")
  end

  def normalize(value)
    value.to_s.strip.downcase
  end
end
