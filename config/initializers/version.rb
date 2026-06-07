module Sure
  class << self
    def version
      Semver.new(semver)
    end

    def latest_version_available?
      VersionChecker.update_available?
    end

    def latest_release_url
      VersionChecker.release_url
    end

    def commit_sha
      if Rails.env.production?
        ENV["BUILD_COMMIT_SHA"]
      else
        `git rev-parse HEAD`.chomp
      end
    end

    private
      def semver
        # Priority 1: Environment variable (for production builds)
        if ENV["APP_VERSION"].present?
          version = ENV["APP_VERSION"].sub(/^v/, "")
          # Validate version format (simple semver check)
          return version if version.match?(/\A\d+\.\d+\.\d+\z/)
        end

        # Priority 2: Read from git tag (for development/test)
        git_version = read_version_from_git_tag
        return git_version if git_version.present?

        # Priority 3: Fallback to hardcoded version for offline/disconnected environments
        "0.22.0"
      end

      def read_version_from_git_tag
        # Only read from git in development/test environments
        # Production should use ENV["APP_VERSION"] set during build
        return nil if Rails.env.production?

        begin
          # Get latest tag
          tag = `git describe --tags --abbrev=0 2>/dev/null`.chomp
          return nil if tag.blank?

          # Remove 'v' prefix if present and return version
          tag.sub(/^v/, "")
        rescue StandardError
          nil
        end
      end
  end
end
