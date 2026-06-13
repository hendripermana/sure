class Provider::Stripe::EventProcessor
  def initialize(event)
    @event = event
  end

  def process
    raise NotImplementedError, "Subclasses must implement the process method"
  end

  private
    attr_reader :event

    def event_data
      event.data.object
    end

    def event_id
      event.respond_to?(:id) ? event.id : event["id"]
    end

    def event_type
      event.respond_to?(:type) ? event.type : event["type"]
    end

    def event_created_at
      event.respond_to?(:created) ? event.created : event["created"]
    end
end
