class HealthCheckService
    def self.start
        Thread.new do
            loop do
                begin
                    healthy = TcpConnectionPool.instance.healthy?

                    if healthy
                        puts "[HealthCheck] TCP pool is healthy"
                        request = {
                            id: SecureRandom.uuid,
                            action: 'health-check',
                            timestamp: Time.now.to_i,
                        }
                        message = SampleMessage.new(request)
                      
                        TcpConnectionPool.instance.send_request(message)
                    else
                        puts "[HealthCheck] TCP pool is unhealthy"
                    end
                rescue => e
                    puts "[HealthCheck] Error: #{e.message}"
                ensure
                    sleep 10
                end
            end
        end
    end
end
