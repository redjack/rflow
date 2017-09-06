class RFlow
  # Components.
  module Components
    # A component that replicates all inbound messages onto a single out port in
    # order to easily support a many-to-many connection pattern (connect all the
    # ins to this component and all the outs to this component instead of
    # all of the ins to all of the outs).
    #
    # Emits {RFlow::Message}s of whatever type was sent in. Any messages with
    # problems being sent to {out} will be sent to {errored} instead.
    class Replicate < Component
      # @!attribute [r] in
      #   Receives {RFlow::Message}s.
      #   @return [Component::InputPort]
      input_port :in
      # @!attribute [r] out
      #   Outputs {RFlow::Message}s.
      #   @return [Component::OutputPort]
      output_port :out
      # @!attribute [r] errored
      #   Outputs {RFlow::Messages}s that could not be sent to {errored}.
      #   @return [Component::OutputPort]
      output_port :errored

      # RFlow-called method on message arrival.
      # @return [void]
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
