require 'active_record'

class RFlow
  class Configuration
    class Connection < ActiveRecord::Base
      class ConnectionInvalid < StandardError; end
      include ActiveModel::Validations

      serialize :options, Hash
      
      belongs_to :input_port, :primary_key => 'uuid', :foreign_key => 'input_port_uuid'
      belongs_to :output_port,:primary_key => 'uuid', :foreign_key => 'output_port_uuid'

      validates_uniqueness_of :uuid, :output_port_uuid
    end

    # STI Subclass
    class ZMQConnection < Connection
      REQUIRED_OPTIONS = []
      DEFAULT_OPTIONS = {}
    end

    class AMQPConnection < Connection
    end
  end
end

