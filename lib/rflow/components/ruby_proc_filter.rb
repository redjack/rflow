class RFlow
  module Components
    class RubyProcFilter < Component
      input_port :in
      output_port :filtered
      output_port :dropped
      output_port :errored

      def configure!(config)
        @filter_proc = eval("lambda {|message| #{config['filter_proc_string']} }")
      end

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
