class EchoBackService
    def execute(received_message)
        request = {
            action: 'echo-back',
            timestamp: Time.now.to_i,
        }
        message = EchoBackMessage.new(request)
    
        TcpConnectionPool.instance.send_request(message)
    end
end
