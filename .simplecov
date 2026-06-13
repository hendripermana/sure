# SimpleCov configuration for Sure Rails application
# This file configures test coverage reporting

require 'simplecov'
require 'simplecov-cobertura'

SimpleCov.start 'rails' do
  # Coverage output directory
  coverage_dir 'coverage'

  # Minimum coverage threshold
  minimum_coverage 80
  minimum_coverage_by_file 70

  # Refuse dropping coverage
  refuse_coverage_drop

  # Formatters for different output formats
  formatters = [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::CoberturaFormatter
  ]

  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(formatters)

  # Groups for better organization
  add_group 'Controllers', 'app/controllers'
  add_group 'Models', 'app/models'
  add_group 'Helpers', 'app/helpers'
  add_group 'Mailers', 'app/mailers'
  add_group 'Jobs', 'app/jobs'
  add_group 'Services', 'app/services'
  add_group 'Policies', 'app/policies'
  add_group 'Decorators', 'app/decorators'
  add_group 'Serializers', 'app/serializers'
  add_group 'Libraries', 'lib'

  # Files to exclude from coverage
  add_filter '/test/'
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'
  add_filter '/db/'
  add_filter 'app/channels/application_cable/'
  add_filter 'app/jobs/application_job.rb'
  add_filter 'app/mailers/application_mailer.rb'
  add_filter 'app/models/application_record.rb'
  add_filter 'app/controllers/application_controller.rb'

  # Track files even if they're not loaded during tests
  track_files '{app,lib}/**/*.rb'

  # Enable branch coverage (Ruby 2.5+)
  enable_coverage :branch if RUBY_VERSION >= '2.5'

  # Merge results from different test runs
  merge_timeout 3600
end

# Only start SimpleCov if COVERAGE environment variable is set
if ENV['COVERAGE'] == 'true'
  SimpleCov.start
end
