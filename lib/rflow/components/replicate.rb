class RFlow
  module Components
    class Replicate < Component
      input_port :in
      output_port :out
      output_port :errored

      def process_message(input_port, input_port_key, connection, message)
        out.each do |connections|
          begin
            connections.send_message message
          rescue Exception => e
            RFlow.logger.debug "#{self.class} Message caused exception: #{e.class}: #{e.message}: #{e.backtrace}"
            errored.send_message message
          end
        end
      end
    end
  end
end
