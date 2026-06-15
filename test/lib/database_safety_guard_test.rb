# frozen_string_literal: true

require "test_helper"

# Guards the issue 003 contract that the suite can never run against a
# production database, even when conflicting POSTGRES_DB / POSTGRES_DB_PRODUCTION
# shell variables resolve the test environment onto a production database name.
class DatabaseSafetyGuardTest < ActiveSupport::TestCase
  test "returns the configured database when it is a safe test database" do
    assert_equal "sure_test", DatabaseSafetyGuard.verify!(
      rails_env: "test",
      configured_database: "sure_test",
      production_database: "sure_production"
    )
  end

  test "raises outside the test environment" do
    error = assert_raises(DatabaseSafetyGuard::UnsafeDatabaseError) do
      DatabaseSafetyGuard.verify!(
        rails_env: "development",
        configured_database: "sure_test",
        production_database: "sure_production"
      )
    end

    assert_match(/test environment/i, error.message)
  end

  test "raises when the configured database collides with the production database" do
    error = assert_raises(DatabaseSafetyGuard::UnsafeDatabaseError) do
      DatabaseSafetyGuard.verify!(
        rails_env: "test",
        configured_database: "sure_production",
        production_database: "sure_production"
      )
    end

    assert_match(/production database/i, error.message)
  end

  test "raises when the configured database is blank" do
    assert_raises(DatabaseSafetyGuard::UnsafeDatabaseError) do
      DatabaseSafetyGuard.verify!(
        rails_env: "test",
        configured_database: "",
        production_database: "sure_production"
      )
    end
  end

  test "comparison ignores surrounding whitespace and case" do
    assert_raises(DatabaseSafetyGuard::UnsafeDatabaseError) do
      DatabaseSafetyGuard.verify!(
        rails_env: "test",
        configured_database: "  Sure_Production ",
        production_database: "sure_production"
      )
    end
  end
end
