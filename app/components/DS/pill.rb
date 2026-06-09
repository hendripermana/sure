# frozen_string_literal: true

# Generic inline pill primitive. Two modes:
#
# - `marker: true` (default) — uppercase 10/11px text, tracking-wide.
#   Reads as a stage marker (Beta, Canary, NEW, PRO, EXPERIMENTAL).
#
# - `marker: false` — normal case, snaps to the DS text scale
#   (`text-xs` / `text-sm`). Reads as a status / category badge.
#   Pair with semantic tones (:success, :warning, :error, :info, :neutral)
#   for status badges; pair with visual tones (:violet, :indigo, etc.)
#   for category tags.
#
# Tones accept both visual names and semantic aliases.
class DS::Pill < DesignSystemComponent
  TONES = %i[violet indigo fuchsia amber green gray red].freeze
  STYLES = %i[soft filled outline].freeze
  SIZES = %i[sm md].freeze

  SEMANTIC_TONE_ALIASES = {
    success:     :green,
    warning:     :amber,
    error:       :red,
    destructive: :red,
    info:        :indigo,
    neutral:     :gray
  }.freeze

  attr_reader :label, :tone, :style, :size, :show_dot, :dot_only, :title,
              :icon, :marker, :custom_color, :truncate, :label_testid, :icon_size

  def initialize(label: nil, tone: :violet, style: :soft, size: :sm,
                 show_dot: nil, dot_only: false, title: nil, icon: nil,
                 marker: true, custom_color: nil, truncate: false,
                 label_testid: nil, icon_size: "xs")
    resolved_tone = SEMANTIC_TONE_ALIASES.fetch(tone.to_sym, tone.to_sym)
    @label = label || "Beta"
    @tone = TONES.include?(resolved_tone) ? resolved_tone : :violet
    @style = STYLES.include?(style.to_sym) ? style.to_sym : :soft
    @size = SIZES.include?(size.to_sym) ? size.to_sym : :sm
    @show_dot = show_dot.nil? ? marker : show_dot
    @dot_only = dot_only
    @title = title
    @icon = icon
    @marker = marker
    @custom_color = custom_color
    @truncate = truncate
    @label_testid = label_testid
    @icon_size = icon_size
  end

  def palette
    {
      violet:  { bg: "var(--color-violet-50)",  bg_dark: "var(--color-violet-tint-10)",  text: "color-mix(in oklab, var(--color-violet-700), black 30%)",  text_dark: "var(--color-violet-200)",  border: "var(--color-violet-200)",  dot: "var(--color-violet-500)",  fill: "var(--color-violet-500)" },
      indigo:  { bg: "var(--color-indigo-50)",  bg_dark: "var(--color-indigo-tint-10)",  text: "color-mix(in oklab, var(--color-indigo-700), black 30%)",  text_dark: "var(--color-indigo-200)",  border: "var(--color-indigo-200)",  dot: "var(--color-indigo-500)",  fill: "var(--color-indigo-500)" },
      fuchsia: { bg: "var(--color-fuchsia-50)", bg_dark: "var(--color-fuchsia-tint-10)", text: "color-mix(in oklab, var(--color-fuchsia-700), black 30%)", text_dark: "var(--color-fuchsia-200)", border: "var(--color-fuchsia-200)", dot: "var(--color-fuchsia-500)", fill: "var(--color-fuchsia-500)" },
      amber:   { bg: "var(--color-yellow-50)",  bg_dark: "var(--color-yellow-tint-10)",  text: "color-mix(in oklab, var(--color-yellow-700), black 30%)",  text_dark: "var(--color-yellow-200)",  border: "var(--color-yellow-200)",  dot: "var(--color-yellow-500)",  fill: "var(--color-yellow-500)" },
      green:   { bg: "var(--color-green-50)",   bg_dark: "var(--color-green-tint-10)",   text: "color-mix(in oklab, var(--color-green-700), black 30%)",   text_dark: "var(--color-green-200)",   border: "var(--color-green-200)",   dot: "var(--color-green-500)",   fill: "var(--color-green-500)" },
      gray:    { bg: "var(--color-gray-100)",   bg_dark: "var(--color-gray-tint-10)",    text: "color-mix(in oklab, var(--color-gray-700), black 30%)",    text_dark: "var(--color-gray-200)",    border: "var(--color-gray-200)",    dot: "var(--color-gray-500)",    fill: "var(--color-gray-500)" },
      red:     { bg: "var(--color-red-50)",     bg_dark: "var(--color-red-tint-10)",     text: "color-mix(in oklab, var(--color-red-700), black 30%)",     text_dark: "var(--color-red-200)",     border: "var(--color-red-200)",     dot: "var(--color-red-500)",     fill: "var(--color-red-500)" }
    }[tone]
  end

  def dot_size_px
    size == :md ? 6 : 5
  end

  def container_styles
    return custom_color_styles if custom_color.present?

    p = palette
    case style
    when :filled
      strong_fill = p[:fill].sub("-500)", "-700)")
      <<~CSS.strip.gsub(/\s+/, " ")
        background-color: #{strong_fill};
        color: var(--color-white);
        border-color: transparent;
      CSS
    when :outline
      <<~CSS.strip.gsub(/\s+/, " ")
        background-color: transparent;
        color: light-dark(#{p[:text]}, #{p[:text_dark]});
        border-color: light-dark(#{p[:border]}, color-mix(in oklab, #{p[:dot]} 40%, transparent));
      CSS
    else
      <<~CSS.strip.gsub(/\s+/, " ")
        background-color: light-dark(#{p[:bg]}, #{p[:bg_dark]});
        color: light-dark(#{p[:text]}, #{p[:text_dark]});
        border-color: light-dark(#{p[:border]}, color-mix(in oklab, #{p[:dot]} 20%, transparent));
      CSS
    end
  end

  def dot_color
    return custom_color if custom_color.present?
    style == :filled ? "rgba(255,255,255,0.85)" : palette[:dot]
  end

  def custom_color_styles
    case style
    when :filled
      <<~CSS.strip.gsub(/\s+/, " ")
        background-color: #{custom_color};
        color: var(--color-white);
        border-color: transparent;
      CSS
    when :outline
      <<~CSS.strip.gsub(/\s+/, " ")
        background-color: transparent;
        color: #{custom_color};
        border-color: color-mix(in oklab, #{custom_color} 40%, transparent);
      CSS
    else
      <<~CSS.strip.gsub(/\s+/, " ")
        background-color: color-mix(in oklab, #{custom_color} 10%, transparent);
        color: #{custom_color};
        border-color: color-mix(in oklab, #{custom_color} 20%, transparent);
      CSS
    end
  end

  def container_classes
    base = [
      "inline-flex items-center align-middle font-medium",
      truncate ? "max-w-full min-w-0" : "whitespace-nowrap shrink-0",
      "border leading-none"
    ]

    if marker
      base << "rounded-md uppercase"
      base << (size == :md ? "px-2 py-0.5 text-[11px] tracking-wide gap-1" : "px-1.5 py-0.5 text-[10px] tracking-wider gap-1")
    else
      base << "rounded-full"
      base << (size == :md ? "px-2 py-0.5 text-sm gap-1.5" : "px-1.5 py-0.5 text-xs gap-1")
    end
    class_names(*base)
  end
end
