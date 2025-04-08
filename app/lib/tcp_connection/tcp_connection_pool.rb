class TcpConnectionPool
  include Singleton

  def initialize
    @connections = []
    @counter = Concurrent::AtomicFixnum.new(0)
    @connection_configs = [
      { host: '127.0.0.1', port: 1234 },
      { host: '127.0.0.1', port: 1235 }
    ]
    initialize_connections
  end

  def send_request(payload, priority: :normal)
    connection = pick_connection
    if connection
      connection.send_request(payload, priority: priority)
    else
      raise "No healthy TCP connections available"
    end
  end

  def healthy?
    healthy_connections = @connections.select(&:healthy?)
    healthy_connections.size > 0
  end

  private

  def initialize_connections
    @connection_configs.each do |config|
      connection = LongLivedTcpConnection.new(config[:host], config[:port])
      @connections << connection
    end
  end

  def pick_connection
    healthy_connections = @connections.select(&:healthy?)
    return nil if healthy_connections.empty?

    # Evenly distributing the requests across the connections, can be improved by applying other algorithms like round robin
    index = @counter.increment % healthy_connections.size
    healthy_connections[index]
  end
end
