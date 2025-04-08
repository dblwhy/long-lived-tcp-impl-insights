class SampleService
  def execute
    request = {
      id: SecureRandom.uuid,
      action: 'test',
      timestamp: Time.now.to_i,
    }
    message = SampleMessage.new(request)

    correlation_id = TcpConnectionPool.instance.send_message(message)
    response = TcpConnectionPool.instance.wait_for_response(correlation_id)

    puts response
  end
end
