# frozen_string_literal: true

# A single-select pill group — filters, mode switches, compact view toggles.
# NOT the full ARIA tab/panel widget; use DS::Tabs for tabs-with-panels.
#
# Each segment is a link (pass `href:`) or a button (default — pass `data:`
# for a Stimulus-driven control). Mark the current one with `active: true`.
#
# `full_width: true` stretches segments to equal width.
class DS::SegmentedControl < DesignSystemComponent
  renders_many :segments, ->(label, active: false, href: nil, **opts) do
    classes = class_names(
      "segmented-control__segment",
      ("flex-1" if full_width),
      ("segmented-control__segment--active" if active),
      opts.delete(:class)
    )

    if href
      link_to(label, href, class: classes, "aria-current": (active ? "true" : nil), **opts)
    else
      content_tag(:button, label, type: "button", class: classes, "aria-pressed": active.to_s, **opts)
    end
  end

  attr_reader :full_width, :aria_label

  def initialize(full_width: false, aria_label: nil, **opts)
    @full_width = full_width
    @aria_label = aria_label
    @opts = opts
  end

  erb_template <<~ERB
    <%= content_tag :div,
          class: class_names("segmented-control", ("w-full" if full_width), @opts[:class]),
          role: "group",
          "aria-label": aria_label,
          **@opts.except(:class) do %>
      <% segments.each do |segment| %><%= segment %><% end %>
    <% end %>
  ERB
end
