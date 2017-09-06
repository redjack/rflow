class RFlow
  # @!parse
  #   class Message
  #     class Data
  #       # Message emitted by {RFlow::Components::GenerateIntegerSequence}.
  #       # Of course the real class is {RFlow::Message} with type +RFlow::Message::Data::Integer+.
  #       #
  #       # {RFlow::Message::Data#data_object} will return the integer.
  #       class Integer
  #         # Just here to force Yard to create documentation.
  #         # @!visibility private
  #         def initialize; end
  #       end
  #     end
  #   end

  # Components.
  module Components
    Configuration.add_available_data_type('RFlow::Message::Data::Integer', 'avro', '{"type": "long"}')

    # An integer sequence generator that ticks every _n_ seconds.
    #
    # Accepts config parameters:
    # - +start+ - the number to start at (defaults to +0+)
    # - +finish+ - the number to finish at (defaults to +0+; no numbers greater than this will be emitted)
    # - +step+ - the number to step (defaults to +1+)
    # - +interval_seconds+ - how long to wait, in seconds, between ticks (defaults to +0+)
    #
    # Emits {RFlow::Message}s whose internal type is {RFlow::Message::Data::Integer}.
    class GenerateIntegerSequence < Component
      # @!attribute [r] out
      #   Outputs {RFlow::Message::Data::Integer} messages.
      #   @return [Component::OutputPort]
      output_port :out
      # @!attribute [r] even_odd_out
      #   Outputs the same messages as {out}. Also addressable with subports +even+ and +odd+
      #   to select those subsequences.
      #   @return [Component::OutputPort]
      output_port :even_odd_out

      # RFlow-called method at startup.
      # @param config [Hash] configuration from the RFlow config file
      # @return [void]
      def configure!(config)
        @start = config['start'].to_i
        @finish = config['finish'].to_i
        @step = config['step'] ? config['step'].to_i : 1
        # If interval seconds is not given, it will default to 0
        @interval_seconds = config['interval_seconds'].to_i
      end

      # RFlow-called method at startup.
      # @return [void]
      def run!
        # Note that this uses the timer (sometimes with 0 interval) so as
        # not to block the reactor.
        @timer = EM::PeriodicTimer.new(@interval_seconds) { generate }
      end

      # @!visibility private
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
