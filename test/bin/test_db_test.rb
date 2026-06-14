# frozen_string_literal: true

require "test_helper"
require "open3"

class TestDbTest < ActiveSupport::TestCase
  test "CI env uses the external PostgreSQL connection settings" do
    stdout, stderr, status = Open3.capture3(
      {
        "DB_HOST" => "postgres.internal",
        "DB_PORT" => "5544",
        "POSTGRES_USER" => "ci_user",
        "POSTGRES_PASSWORD" => "ci_password",
        "POSTGRES_DB_TEST" => "sure_ci_test",
        "TEST_DB_HOST" => nil,
        "TEST_DB_PORT" => nil,
        "TEST_DB_PASSWORD" => nil
      },
      Rails.root.join("bin/test-db").to_s,
      "--ci",
      "env"
    )

    assert status.success?, stderr
    assert_includes stdout, "export DB_HOST=postgres.internal"
    assert_includes stdout, "export DB_PORT=5544"
    assert_includes stdout, "export POSTGRES_USER=ci_user"
    assert_includes stdout, "export POSTGRES_PASSWORD=ci_password"
    assert_includes stdout, "export POSTGRES_DB_TEST=sure_ci_test"
  end
end
