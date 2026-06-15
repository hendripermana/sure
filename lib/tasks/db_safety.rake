# frozen_string_literal: true

# Prevent destructive database operations from accidentally running against the
# production database while working locally. Set ALLOW_PRODUCTION_DB_TASKS=1 to
# override this guard intentionally (e.g., initial provisioning).
namespace :db do
  task ensure_safe_target: :load_config do
    next if ENV["ALLOW_PRODUCTION_DB_TASKS"] == "1"

    env_name = ENV["RAILS_ENV"].presence || ENV["RACK_ENV"].presence || Rails.env

    configs = ActiveRecord::Base.configurations
    config = configs.respond_to?(:configs_for) ? configs.configs_for(env_name: env_name).first : configs[env_name]
    target_db = config&.database || ENV["POSTGRES_DB"]

    production_db = ENV["POSTGRES_DB_PRODUCTION"].presence || "permoney_production"

    if env_name != "production" && target_db.present? && target_db == production_db
      abort <<~MSG
        Aborting #{env_name} database task: it points to the production database (#{production_db}).

        Copy `.env.local.example` to `.env.local` and set POSTGRES_DB_DEVELOPMENT / POSTGRES_DB_TEST
        so local commands never hit production. If you really intend to run this task against
        production, set ALLOW_PRODUCTION_DB_TASKS=1 explicitly.
      MSG
    end

    if env_name == "test" && target_db.present?
      pattern_str = ENV["APPROVED_TEST_DATABASES_PATTERN"].presence || "_test$"
      begin
        approved_pattern = Regexp.new(pattern_str)
      rescue RegexpError => error
        abort "APPROVED_TEST_DATABASES_PATTERN is invalid: #{error.message}"
      end

      unless target_db.match?(approved_pattern)
        abort <<~MSG
          Aborting test database task: '#{target_db}' is not an approved test database.

          Test databases must match the pattern: #{pattern_str.inspect}
          Set POSTGRES_DB_TEST to a database name matching this pattern, or override with
          the APPROVED_TEST_DATABASES_PATTERN environment variable.
        MSG
      end
    end
  end
end

if defined?(Rake::Task)
  %w[
    db:create
    db:drop
    db:reset
    db:setup
    db:schema:load
    db:structure:load
    db:test:prepare
    db:test:load
    db:test:purge
  ].each do |task_name|
    begin
      task = Rake::Task[task_name]
      task.enhance([ "db:ensure_safe_target" ]) unless task.prerequisites.include?("db:ensure_safe_target")
    rescue RuntimeError
      # Ignore tasks that may not be defined in the current environment
    end
  end
end
