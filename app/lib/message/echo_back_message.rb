class EchoBackMessage < BaseMessage
    def initialize(message)
      @message = message
    end
  
    def correlation_id
      return nil
    end
  
    def parse_buffer(buffer)
        message = JSON.parse(buffer)
        [message, nil]
    rescue JSON::ParserError => e
        [nil, nil]
    end

    def to_buffer
        raise NotImplementedError, "Subclasses must implement to_buffer"
    end
end
