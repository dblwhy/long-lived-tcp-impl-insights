# Long Lived TCP Impl Insights

## Overview

Seeking the best way to handle long lived tcp session in ruby.

Hard requirements:

- Completely decouple the business logic from TCP handler
  - This is because usually the read message handler get convoluted when there are multiple ways to parse/handle the message
- Allow handling multiple tcp sessions and load balancing the transaction
- Support sending health check message periodically and also responds to the 3rd party initiated health check message
- Will not lose messages even tcp connection has terminated temporarily
- Allow sending high priority messages even normal messages exists in the message queue
    - Imagining a scenario where we need to send a specific message to a third-party service to indicate that we are beginning to transmit messages

## Note

- Code is neither executable nor tested, it is aiming for sharing the insight
