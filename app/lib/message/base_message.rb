class BaseMessage
  def initialize; end

  def correlation_id
    raise NotImplementedError, "Subclasses must implement correlation_id"
  end

  def parse_buffer(buffer)
    # Please do not raise exception, just return nil instead
    # because tcp client attempts to parse messages using all parsers
    raise NotImplementedError, "Subclasses must implement parse_buffer"
  end

  def to_buffer
    raise NotImplementedError, "Subclasses must implement to_buffer"
  end
end
