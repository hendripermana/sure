# frozen_string_literal: true

require "test_helper"
require "yaml"

# Guards the blocking-quality contract from issue 002.
#
# These static assertions fail loudly if any future change silently downgrades
# a merge-blocking check (lint, autoload, or security) back into a permissive
# or non-blocking mode. They parse the checked-in CI workflow rather than
# executing it, so they require no network, database, or runner.
class CiWorkflowTest < ActiveSupport::TestCase
  WORKFLOW_PATH = Rails.root.join(".github/workflows/ci.yml")

  setup do
    @raw = File.read(WORKFLOW_PATH)
    @workflow = YAML.safe_load(@raw, aliases: true)
    @jobs = @workflow.fetch("jobs")
    @run_steps = @jobs.values.flat_map { |job| Array(job["steps"]) }
                      .filter_map { |step| step["run"] }
  end

  test "no job suppresses failures with continue-on-error" do
    offenders = @jobs.select { |_name, job| job["continue-on-error"] }.keys
    assert_empty offenders,
      "CI jobs must block on failure; remove continue-on-error from: #{offenders.join(", ")}"
  end

  test "Brakeman runs as a blocking security check" do
    brakeman = @run_steps.find { |cmd| cmd.include?("bin/brakeman") }
    assert brakeman, "CI must run bin/brakeman"
    refute_includes brakeman, "--no-exit-on-warn",
      "Brakeman must not suppress a failing exit on actionable findings"
    assert_includes brakeman, "--exit-on-warn",
      "Brakeman must exit non-zero on warnings to block merges"
  end

  test "JavaScript dependencies install from a frozen lockfile" do
    install = @run_steps.find { |cmd| cmd.include?("pnpm install") }
    assert install, "CI must install JavaScript dependencies with pnpm"
    refute_includes install, "--no-frozen-lockfile",
      "CI must not use permissive --no-frozen-lockfile dependency installation"
    assert_includes install, "--frozen-lockfile",
      "CI must install JavaScript dependencies from a frozen lockfile"
  end

  test "every named blocking check is present in the workflow" do
    required = {
      "bin/rails zeitwerk:check" => "Zeitwerk autoload verification",
      "bin/rubocop" => "RuboCop Ruby lint",
      "pnpm run lint" => "Biome JavaScript lint",
      "bin/brakeman" => "Brakeman security scan",
      "bin/importmap audit" => "Importmap dependency audit"
    }

    required.each do |command, description|
      assert @run_steps.any? { |cmd| cmd.include?(command) },
        "CI must run #{description} (`#{command}`) as a blocking check"
    end
  end

  test "the npm lockfile is absent and a pnpm lockfile is present" do
    refute File.exist?(Rails.root.join("package-lock.json")),
      "package-lock.json must be removed; pnpm is the only package manager"
    assert File.exist?(Rails.root.join("pnpm-lock.yaml")),
      "pnpm-lock.yaml must be checked in"
  end

  test "the pnpm version is pinned in package.json" do
    package = JSON.parse(File.read(Rails.root.join("package.json")))
    assert_match(/\Apnpm@\d+\.\d+\.\d+\z/, package["packageManager"].to_s,
      "package.json must pin an exact pnpm version via packageManager")
  end

  # Guards the issue 003 contract: the full Minitest suite is a blocking CI check
  # that runs against a freshly loaded PostgreSQL 18 database via the disposable
  # harness — never a narrowed subset, never permissive.
  test "the full Minitest suite runs as a blocking job on the clean PostgreSQL 18 path" do
    test_job = @jobs.values.find do |job|
      Array(job["steps"]).any? { |step| step["run"].to_s.include?("bin/rails test") }
    end
    assert test_job, "CI must run the full Minitest suite (`bin/rails test`)"

    refute test_job["continue-on-error"],
      "The test job must block on failure; remove continue-on-error"

    suite_cmd = Array(test_job["steps"]).filter_map { |step| step["run"] }
                     .find { |cmd| cmd.include?("bin/rails test") }
    assert_includes suite_cmd, "bin/test-db",
      "The suite must run through the disposable-database harness (bin/test-db) for a clean schema load"
    refute_match(%r{bin/rails test\s+\S}, suite_cmd,
      "CI must run the entire suite, not a narrowed subset of files")

    postgres_image = test_job.dig("services", "postgres", "image").to_s
    assert_equal "postgres:18", postgres_image,
      "The suite must run against a clean PostgreSQL 18 service"
  end

  test "the test suite job is reached on pull requests" do
    pr_workflow = YAML.safe_load(File.read(Rails.root.join(".github/workflows/pr.yml")), aliases: true)
    triggers = pr_workflow["on"] || pr_workflow[true]
    assert triggers.key?("pull_request"),
      "pr.yml must trigger on pull_request so the blocking suite runs before merge"

    calls_ci = pr_workflow.fetch("jobs").values.any? do |job|
      job["uses"].to_s.include?(".github/workflows/ci.yml")
    end
    assert calls_ci, "pr.yml must invoke ci.yml (which contains the blocking test suite)"
  end
end
