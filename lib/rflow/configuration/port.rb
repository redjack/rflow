require 'active_record'

class RFlow
  class Configuration
    class Port < ActiveRecord::Base
      include ActiveModel::Validations
      
      class PortInvalid < StandardError; end

      belongs_to :component,  :primary_key => 'uuid', :foreign_key => 'component_uuid'
    end

    # STI-based classes
    class InputPort < Port;
      has_one :incoming_connection, :class_name => 'RFlow::Configuration::Connection', :primary_key => 'uuid', :foreign_key => 'input_port_uuid'
      has_many :output_ports, :through => :connections
    end

    class OutputPort < Port;
      has_one :outgoing_connection, :class_name => 'RFlow::Configuration::Connection', :primary_key => 'uuid', :foreign_key => 'output_port_uuid'
      has_one :input_port, :through => :connections
    end
  end
end

