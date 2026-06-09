# frozen_string_literal: true

# `DS::SearchInput` is the search-field primitive.
#
# Two variants:
# - `:standalone` (default) — top-of-list filter inputs. Bordered
#   bg-container surface, icon-on-left, full focus ring.
# - `:embedded` — search-inside-a-panel (DS::Select internal search,
#   DS::Popover filters). No own border/focus ring — parent panel provides chrome.
class DS::SearchInput < DesignSystemComponent
  VARIANTS = %i[standalone embedded].freeze

  attr_reader :variant, :name, :placeholder, :value, :aria_label, :extra_classes, :opts

  def initialize(variant: :standalone, name: nil, placeholder: nil, value: nil, aria_label: nil, class: nil, **opts)
    @variant = variant.to_sym
    @name = name
    @placeholder = placeholder
    @value = value
    @aria_label = aria_label || placeholder
    @extra_classes = binding.local_variable_get(:class)
    @opts = opts

    raise ArgumentError, "Invalid variant: #{@variant}. Must be one of #{VARIANTS.inspect}" unless VARIANTS.include?(@variant)
  end

  def container_classes
    class_names("relative", extra_classes)
  end

  def input_classes
    case variant
    when :embedded
      "bg-container text-primary text-base sm:text-sm placeholder:text-secondary font-normal " \
        "h-10 pl-10 w-full border-none rounded-lg " \
        "focus:outline-hidden focus:ring-0"
    else
      "block w-full border border-secondary rounded-md py-2.5 pl-10 pr-3 bg-container text-base sm:text-sm " \
        "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-gray-900 " \
        "theme-dark:focus-visible:outline-white"
    end
  end
end
