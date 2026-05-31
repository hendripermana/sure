require_relative 'config/environment'
form = ActionView::Helpers::FormBuilder.new(:entry, Entry.new, ActionView::Base.empty, {})
puts form.label(:amount)
puts form.number_field(:amount)
