class RFlow
  # Components.
  module Components
    # Component that filters messages based on Ruby defined in the RFlow config file.
    # Inbound messages will be sent out {filtered} if the predicate returns truthy,
    # {dropped} if it returns falsey, or {errored} if it raises an exception.
    #
    # Accept config parameter +filter_proc_string+ which is the text of a +lambda+
    # receiving a message +message+. For example, +message.data.data_object['foo'] > 2+.
    class RubyProcFilter < Component
      # @!attribute [r] in
      #   Receives {RFlow::Message}s.
      #   @return [Component::InputPort]
      input_port :in
      # @!attribute [r] filtered
      #   Outputs {RFlow::Message}s that pass the filter predicate.
      #   @return [Component::OutputPort]
      output_port :filtered
      # @!attribute [r] dropped
      #   Outputs {RFlow::Message}s that do not pass the filter predicate.
      #   @return [Component::OutputPort]
      output_port :dropped
      # @!attribute [r] errored
      #   Outputs {RFlow::Message}s that raise from the filter predicate.
      #   @return [Component::OutputPort]
      output_port :errored

      # RFlow-called method at startup.
      # @param config [Hash] configuration from the RFlow config file
      # @return [void]
      def configure!(config)
        @filter_proc = eval("lambda {|message| #{config['filter_proc_string']} }")
      end

      # RFlow-called method on message arrival.
      # @return [void]
      def process_message(input_port, input_port_key, connection, message)
        begin
          if @filter_proc.call(message)
            filtered.send_message message
          else
            dropped.send_message message
          end
        rescue Exception => e
          RFlow.logger.debug "#{self.class} Message caused exception: #{e.class}: #{e.message}: #{e.backtrace}"
          errored.send_message message
        end
      end
    end
  end
end
