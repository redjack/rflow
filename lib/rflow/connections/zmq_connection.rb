require 'rflow/connection'

require 'ffi'
require 'ffi-rzmq'


class RFlow
  module Connections
    class ZMQConnection < RFlow::Connection

      def connect_input!
        puts "Connecting input #{instance_uuid}"
        p configuration.find_all {|k, v| k.to_s =~ /input/}
      end

      def connect_output!
        puts "Connecting output #{instance_uuid}"
        p configuration.find_all {|k, v| k.to_s =~ /output/}
      end

    end
  end
end
