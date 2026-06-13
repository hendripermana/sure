# frozen_string_literal: true

# Backward compatibility: Rails 8.1 Redis cache store calls ConnectionPool.new
# with a positional hash. connection_pool 3.x expects keyword args only.
# This wrapper converts a single hash arg into keyword args to avoid
# "wrong number of arguments" crashes at boot.
if defined?(ConnectionPool)
  class ConnectionPool
    alias_method :__sure_orig_initialize, :initialize

    def initialize(*args, **kwargs, &block)
      if args.first.is_a?(Hash) && kwargs.empty?
        kwargs = args.shift.transform_keys { |k| k.respond_to?(:to_sym) ? k.to_sym : k }
      end

      __sure_orig_initialize(**kwargs, &block)
    end
  end
end
