class RFlow
  module Components
    Configuration.add_available_data_type('RFlow::Message::Data::Integer', 'avro', '{"type": "long"}')

    class GenerateIntegerSequence < Component
      output_port :out
      output_port :even_odd_out

      def configure!(config)
        @start = config['start'].to_i
        @finish = config['finish'].to_i
        @step = config['step'] ? config['step'].to_i : 1
        # If interval seconds is not given, it will default to 0
        @interval_seconds = config['interval_seconds'].to_i
      end

      # Note that this uses the timer (sometimes with 0 interval) so as
      # not to block the reactor
      def run!
        @timer = EM::PeriodicTimer.new(@interval_seconds) { generate }
      end

      def generate
        Message.new('RFlow::Message::Data::Integer').tap do |m|
          m.data.data_object = @start
          out.send_message m
          if @start % 2 == 0
            even_odd_out['even'].send_message m
          else
            even_odd_out['odd'].send_message m
          end
        end

        @start += @step
        @timer.cancel if @start > @finish && @timer
      end
    end
  end
end
