class DS::MenuItem < DesignSystemComponent
  VARIANTS = %i[link button divider].freeze

  attr_reader :variant, :text, :icon, :href, :method, :destructive, :confirm, :frame, :opts

  def initialize(variant:, text: nil, icon: nil, href: nil, method: :post, destructive: false, confirm: nil, frame: nil, **opts)
    @variant = variant.to_sym
    @text = text
    @icon = icon
    @href = href
    @method = method.to_sym
    @destructive = destructive
    @confirm = confirm
    @frame = frame
    @opts = opts
    raise ArgumentError, "Invalid variant: #{@variant}" unless VARIANTS.include?(@variant)
  end

  def wrapper(&block)
    if variant == :button
      button_to href, method: method, class: container_classes, **merged_opts, &block
    elsif variant == :link
      link_to href, class: container_classes, **merged_opts, &block
    else
      nil
    end
  end

  def text_classes
    [
      "text-sm",
      destructive? ? "text-destructive" : "text-primary"
    ].join(" ")
  end

  def destructive?
    method == :delete || destructive
  end

  private
    def container_classes
      [
        "flex items-center gap-2 p-2 rounded-md w-full",
        destructive? ? "hover:bg-red-tint-5 theme-dark:hover:bg-red-tint-10" : "hover:bg-container-hover"
      ].join(" ")
    end

    def merged_opts
      # Rails 8.1: Fix nil handling - use safe navigation to prevent NoMethodError
      merged_opts = (opts || {}).dup
      data = merged_opts.delete(:data) || {}

      if confirm.present?
        data = data.merge(turbo_confirm: turbo_confirm_data(confirm))
      end

      # Rails 8.1: Frame parameter takes precedence over everything
      # Explicitly check for nil/false/empty to ensure frame parameter is respected
      if frame.present?
        # Convert symbol to string for consistency (Rails expects string for turbo_frame)
        frame_value = frame.to_s
        data = data.merge(turbo_frame: frame_value)
      else
        # Rails 8.1: Default to _top frame for menu items to break out of any parent frames
        # This ensures navigation works correctly when menu is inside a Turbo Frame
        # Only apply default if no frame is explicitly set AND no turbo_frame in data
        unless data.key?(:turbo_frame) || data.key?("turbo_frame")
          data = data.merge(turbo_frame: "_top") if variant == :link || (variant == :button && method == :delete)
        end
      end

      merged_opts.merge(data: data)
    end
end
