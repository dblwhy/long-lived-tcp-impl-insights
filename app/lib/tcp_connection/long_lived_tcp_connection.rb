class LongLivedTcpConnection
  attr_reader :host, :port

  DEFAULT_TIMEOUT = 20 # seconds
  RECONNECT_INTERVAL = 5 # seconds

  def initialize(host, port)
    @host = host
    @port = port

    @high_priority_queue = Queue.new
    @normal_queue = Queue.new
    @response_map = Concurrent::Map.new
    @write_mutex = Mutex.new
    @message_parsers = [SampleMessage.new]
    @response_matcher = Concurrent::Map.new
    @healthy = Concurrent::AtomicBoolean.new(false)
    @connect_mutex = Mutex.new

    connect
    start_reader_thread
    start_dispatcher_thread
    start_reconnect_thread
  end

  def connect
    @connect_mutex.synchronize do
      @socket = TCPSocket.new(@host, @port)
      puts "Connected to #{@host}:#{@port}"
      @healthy.make_true
    end
  rescue => e
    @healthy.make_false
    puts "Failed to connect to #{@host}:#{@port}: #{e.message}"
    raise ConnectionError, "Failed to connect to #{@host}:#{@port}: #{e.message}"
  end

  def send_request(message, priority: :normal, timeout: 5, &block)
    correlation_id = message.correlation_id

    @response_matcher[correlation_id] = { 
      promise: Concurrent::Promise.new,
      timestamp: Time.now,
    } if correlation_id

    if priority == :high
      @high_priority_queue << message
    else
      @normal_queue << message
    end
    
    correlation_id
  rescue => e
    @response_matcher.delete(correlation_id)
    puts "Failed to send message: #{e.message}"
    raise WriteError, "Failed to send message: #{e.message}"
  end

  def wait_for_response(correlation_id, timeout: nil)
    handler = @response_matcher[correlation_id]
    return nil unless handler

    begin
      Timeout.timeout(timeout || DEFAULT_TIMEOUT) do
        handler[:promise].value! # Blocks execution until the promise is resolved.
      end
    rescue Timeout::Error
      @response_matcher.delete(correlation_id)
      puts "Response timeout for correlation ID: #{correlation_id}"
      raise ResponseTimeoutError, "Response timeout for correlation ID: #{correlation_id}"
    end
  end

  def healthy?
    @healthy.true?
  end

  def close
    @socket.close if @socket
    @logger.info("Connection closed")
  rescue => e
    puts "Error closing connection: #{e.message}"
  end

  private

  def start_dispatcher_thread
    Thread.new do
      loop do
        sleep 0.1 while !healthy?

        is_priority = false
        message = if !@high_priority_queue.empty?
                    is_priority = true
                    @high_priority_queue.pop
                  else
                    @normal_queue.pop
                  end

        @write_mutex.synchronize do
          begin
            @socket.write(message.to_buffer)
          rescue => e
            puts "Error writing to socket: #{e.message}"
            @healthy.make_false
            if is_priority
              @high_priority_queue << message
            else
              @normal_queue << message
            end
          end
        end
      end
    rescue => e
      puts "Dispatcher thread error: #{e.message}"
      @healthy.make_false
      # Restart the dispatcher thread if it crashes
      start_dispatcher_thread
    end
  end

  def start_reader_thread
    Thread.new do
      loop do
        sleep 0.1 while !healthy?

        buffer = read_message
        next unless buffer

        message = nil
        @message_parsers.each do |parser|
          message, handler = parser.parse_buffer(buffer)
          break if message
        end
        unless message
          puts "Failed to parse message!"
          next
        end

        correlation_id = message.correlation_id

        if correlation_id && @response_matcher.key?(correlation_id)
          found_hash = @response_matcher.delete(correlation_id)
          found_hash[:promise].fulfill(message)
          puts "Processed response for correlation ID: #{correlation_id}"
        end

        # Post processing if needed such as the message is initiated by the 3rd party service
        handler&.call(message)
      end
    rescue => e
      puts "Reader thread error: #{e.message}"
      @healthy.make_false
      # Restart the reader thread if it crashes
      start_reader_thread
    end
  end

  def start_reconnect_thread
    Thread.new do
      loop do
        sleep RECONNECT_INTERVAL
        next if healthy?
        
        puts "Attempting to reconnect to #{@host}:#{@port}..."
        begin
          connect
          puts "Successfully reconnected to #{@host}:#{@port}"
        rescue => e
          puts "Reconnection failed: #{e.message}"
        end
      end
    end
  end

  def read_message
    len_buf = @socket.read(4)
    return nil unless len_buf

    len = len_buf.unpack1('N')
    @socket.read(len)
  rescue => e
    puts "Error reading message: #{e.message}"
    @healthy.make_false
    nil
  end
end

class ConnectionError < StandardError; end
class WriteError < StandardError; end
class ResponseTimeoutError < StandardError; end
