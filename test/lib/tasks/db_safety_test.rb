# frozen_string_literal: true

require "test_helper"

class DbSafetyTaskTest < ActiveSupport::TestCase
  test "db:ensure_safe_target passes when DB name matches _test pattern" do
    Rails.application.load_tasks
    Rake::Task["db:ensure_safe_target"].reenable
    ClimateControl.modify RAILS_ENV: "test" do
      Rake::Task["db:ensure_safe_target"].invoke
    end
  end

  test "db:ensure_safe_target is bypassed with ALLOW_PRODUCTION_DB_TASKS=1" do
    Rails.application.load_tasks
    Rake::Task["db:ensure_safe_target"].reenable
    ClimateControl.modify ALLOW_PRODUCTION_DB_TASKS: "1" do
      Rake::Task["db:ensure_safe_target"].invoke
    end
  end

  test "db:ensure_safe_target does not abort in non-test environments" do
    Rails.application.load_tasks
    Rake::Task["db:ensure_safe_target"].reenable
    ClimateControl.modify RAILS_ENV: "development",
                          POSTGRES_DB_PRODUCTION: "different_from_real_prod" do
      Rake::Task["db:ensure_safe_target"].invoke
    end
  end

  test "db:schema:load prerequisite chain includes the guard" do
    Rails.application.load_tasks
    Rake::Task["db:ensure_safe_target"].reenable
    Rake::Task["db:schema:load"].reenable
    ClimateControl.modify RAILS_ENV: "test" do
      Rake::Task["db:schema:load"].invoke
    end
  end
end
