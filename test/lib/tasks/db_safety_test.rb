# frozen_string_literal: true

require "test_helper"

class DbSafetyTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("db:ensure_safe_target")
    Rake::Task["db:load_config"].invoke
    Rake::Task["db:ensure_safe_target"].reenable
  end

  test "allows an approved test database" do
    assert_silent do
      invoke_guard(env_name: "test", target_db: "sure_test")
    end
  end

  test "rejects an unapproved test database" do
    _, stderr = capture_io do
      error = assert_raises(SystemExit) do
        invoke_guard(env_name: "test", target_db: "sure_development")
      end

      assert_equal 1, error.status
    end

    assert_includes stderr, "'sure_development' is not an approved test database"
  end

  test "rejects a non-production environment targeting production" do
    _, stderr = capture_io do
      error = assert_raises(SystemExit) do
        invoke_guard(
          env_name: "development",
          target_db: "sure_production",
          production_db: "sure_production"
        )
      end

      assert_equal 1, error.status
    end

    assert_includes stderr, "it points to the production database (sure_production)"
  end

  test "allows an explicit production database override" do
    assert_silent do
      invoke_guard(
        env_name: "development",
        target_db: "sure_production",
        production_db: "sure_production",
        allow_production: "1"
      )
    end
  end

  test "reports an invalid approved database pattern" do
    _, stderr = capture_io do
      error = assert_raises(SystemExit) do
        invoke_guard(
          env_name: "test",
          target_db: "sure_test",
          approved_pattern: "["
        )
      end

      assert_equal 1, error.status
    end

    assert_includes stderr, "APPROVED_TEST_DATABASES_PATTERN is invalid"
  end

  test "db:schema:load prerequisite chain includes the guard" do
    guard_prerequisites = Rake::Task["db:ensure_safe_target"].prerequisites
    schema_prerequisites = Rake::Task["db:schema:load"].prerequisites

    assert_includes guard_prerequisites, "load_config"
    assert_includes schema_prerequisites, "db:ensure_safe_target"
    assert_operator schema_prerequisites.index("load_config"),
                    :<,
                    schema_prerequisites.index("db:ensure_safe_target")
  end

  private

    def invoke_guard(env_name:, target_db:, production_db: "permoney_production",
                     approved_pattern: nil, allow_production: nil)
      config = OpenStruct.new(database: target_db)
      configurations = mock("database configurations")
      configurations.stubs(:configs_for).with(env_name: env_name).returns([ config ])
      ActiveRecord::Base.stubs(:configurations).returns(configurations)

      ClimateControl.modify(
        RAILS_ENV: env_name,
        RACK_ENV: nil,
        POSTGRES_DB: nil,
        POSTGRES_DB_PRODUCTION: production_db,
        APPROVED_TEST_DATABASES_PATTERN: approved_pattern,
        ALLOW_PRODUCTION_DB_TASKS: allow_production
      ) do
        Rake::Task["db:ensure_safe_target"].invoke
      end
    end
end
