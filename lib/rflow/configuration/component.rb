require 'active_record'
require 'rflow/configuration/uuid_keyed'

class RFlow
  class Configuration
    class Component < ConfigurationItem
      include UUIDKeyed
      include ActiveModel::Validations

      serialize :options, Hash

      belongs_to :shard, :primary_key => 'uuid', :foreign_key => 'shard_uuid'
      has_many :input_ports,  :primary_key => 'uuid', :foreign_key => 'component_uuid'
      has_many :output_ports, :primary_key => 'uuid', :foreign_key => 'component_uuid'

      #TODO: Get this to work
      #has_many :input_connections, :through => :input_ports, :source => :input_connections
      #has_many :output_connections, :through => :output_ports, :source => :output_connection

      validates_uniqueness_of :name
    end
  end
end
