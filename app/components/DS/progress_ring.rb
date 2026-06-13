# frozen_string_literal: true

# A single-arc circular progress ring, decoupled from any domain model.
#
# Pass a percent and a tone; the component owns the geometry (radius,
# circumference, dash offset) and the accessible progressbar markup.
class DS::ProgressRing < DesignSystemComponent
  TONES = {
    success: "var(--color-success)",
    warning: "var(--color-warning)",
    destructive: "var(--color-destructive)",
    neutral: "var(--color-gray-400)"
  }.freeze

  DEFAULT_TRACK = "var(--budget-unused-fill)".freeze

  attr_reader :size, :stroke_width, :label, :show_percent

  def initialize(percent:, size: 64, stroke_width: 6, tone: :neutral, label: nil, show_percent: true, track: DEFAULT_TRACK)
    @percent = percent
    @size = size
    @stroke_width = stroke_width
    @tone = tone.to_sym
    @label = label
    @show_percent = show_percent
    @track = track
  end

  def clamped_percent
    [ [ @percent.to_i, 0 ].max, 100 ].min
  end

  def stroke_color
    TONES.fetch(@tone, TONES[:neutral])
  end

  def track_color
    @track
  end

  def center
    size / 2.0
  end

  def radius
    (size - stroke_width) / 2.0
  end

  def circumference
    2 * Math::PI * radius
  end

  def dash_offset
    circumference * (1 - clamped_percent / 100.0)
  end

  def percent_font_px
    (size * 0.17).round
  end

  def wrapper_aria
    return {} if label.blank?
    { role: "progressbar", aria: { valuenow: clamped_percent, valuemin: 0, valuemax: 100, label: label } }
  end
end
