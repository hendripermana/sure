module ApplicationHelper
  # Upstream: Dynamic branding from Rails config (better approach)
  def product_name
    Rails.configuration.x.product_name
  end

  def brand_name
    Rails.configuration.x.brand_name
  end

  def styled_form_with(**options, &block)
    options[:builder] = StyledFormBuilder
    form_with(**options, &block)
  end

  def skeleton_loader(classes = "")
    tag.div class: "bg-gray-200 dark:bg-gray-700 animate-pulse rounded #{classes}"
  end

  def icon(key, size: "md", color: "default", custom: false, as_button: false, **opts)
    extra_classes = opts.delete(:class)
    sizes = { xs: "w-3 h-3", sm: "w-4 h-4", md: "w-5 h-5", lg: "w-6 h-6", xl: "w-7 h-7", "2xl": "w-8 h-8" }
    colors = { default: "fg-gray", white: "fg-inverse", success: "text-success", warning: "text-warning", destructive: "text-destructive", current: "text-current" }

    icon_classes = class_names(
    "shrink-0 transition-all duration-300",
    sizes[size.to_sym],
    colors[color.to_sym],
    extra_classes
  )

    if custom
      inline_svg_tag("#{key}.svg", class: icon_classes, **opts)
    elsif as_button
      render DS::Button.new(variant: "icon", class: extra_classes, icon: key, size: size, type: "button", **opts)
    else
      lucide_icon(key, class: icon_classes, **opts)
    end
  end

  # Convert alpha (0-1) to 8-digit hex (00-FF)
  def hex_with_alpha(hex, alpha)
    alpha_hex = (alpha * 255).round.to_s(16).rjust(2, "0")
    "#{hex}#{alpha_hex}"
  end

  def title(page_title)
    content_for(:title) { page_title }
  end

  def header_title(page_title)
    content_for(:header_title) { page_title }
  end

  def header_description(page_description)
    content_for(:header_description) { page_description }
  end

  def pagy_series(pagy, **options)
    pagy.navigation_series(**options) || []
  end

  def page_active?(path)
    current_page?(path) || (request.path.start_with?(path) && path != "/")
  end

  # Wrapper around I18n.l to support custom date formats
  def format_date(object, format = :default, options = {})
    date = object.to_date

    format_code = options[:format_code] || Current.family&.date_format

    if format_code.present?
      date.strftime(format_code)
    else
      I18n.l(date, format: format, **options)
    end
  end

  def format_money(number_or_money, options = {})
    return nil unless number_or_money

    # Handle Money objects directly to preserve currency
    # Money objects already have correct currency from family/account
    if number_or_money.is_a?(Money)
      number_or_money.format(options)
    else
      # For numbers, create Money object (will use default currency)
      Money.new(number_or_money).format(options)
    end
  end

  def totals_by_currency(collection:, money_method:, separator: " | ", negate: false)
    collection.group_by(&:currency)
              .transform_values { |item| calculate_total(item, money_method, negate) }
              .map { |_currency, money| format_money(money) }
              .join(separator)
  end

  def show_super_admin_bar?
    if params[:admin].present?
      cookies.permanent[:admin] = params[:admin]
    end

    cookies[:admin] == "true"
  end

  # Sure: Time-based greeting (custom feature)
  def time_based_greeting
    hour = Time.current.hour
    if hour >= 5 && hour < 12
      "Good morning"
    elsif hour >= 12 && hour < 18
      "Good afternoon"
    else
      "Good evening"
    end
  end

  # Upstream: Default AI model helper
  def default_ai_model
    # Always return a valid model, never nil or empty
    # Delegates to Chat.default_model for consistency
    Chat.default_model
  end

  # Renders Markdown text using Redcarpet and sanitizes the output
  def markdown(text)
    return "" if text.blank?

    renderer = Redcarpet::Render::HTML.new(
      hard_wrap: true,
      filter_html: true,
      safe_links_only: true,
      link_attributes: { target: "_blank", rel: "noopener noreferrer" }
    )

    markdown = Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      superscript: true,
      underline: true,
      highlight: true,
      quote: true,
      footnotes: true
    )

    allowed_tags = %w[
      a p br ul ol li strong em b i code pre blockquote hr
      h1 h2 h3 h4 h5 h6
      table thead tbody tfoot tr th td
      dl dt dd sup sub mark kbd samp var
    ]
    allowed_attributes = %w[href title target rel class]

    sanitize(markdown.render(text), tags: allowed_tags, attributes: allowed_attributes)
  end

  # Helper to set breadcrumbs from controllers or views
  # Supports both old array format and new hash format with icons
  #
  # Old format (backward compatible):
  #   set_breadcrumbs([["Home", root_path], ["Accounts", accounts_path], ["Show", nil]])
  #
  # New format with icons:
  #   set_breadcrumbs([
  #     { text: "Home", href: root_path, icon: "home" },
  #     { text: "Accounts", href: accounts_path, icon: "folder" },
  #     { text: "Show", icon: "file-text" }
  #   ])
  def set_breadcrumbs(breadcrumbs)
    @breadcrumbs = breadcrumbs
  end

  private
    def calculate_total(item, money_method, negate)
      # Filter out transfer-type transactions from entries
      # Only Entry objects have entryable transactions, Account objects don't
      items = item.reject do |i|
        i.is_a?(Entry) &&
        i.entryable.is_a?(Transaction) &&
        i.entryable.transfer?
      end
      total = items.sum(&money_method)
      negate ? -total : total
    end
end
