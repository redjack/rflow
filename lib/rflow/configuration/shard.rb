require 'active_record'
require 'rflow/configuration/uuid_keyed'

class RFlow
  class Configuration
    class Shard < ConfigurationItem
      include UUIDKeyed
      include ActiveModel::Validations

      class ShardInvalid < StandardError; end

      has_many :components, :primary_key => 'uuid', :foreign_key => 'shard_uuid'

      validates_uniqueness_of :name
      validates_numericality_of :count, :only_integer => true, :greater_than => 0
    end

    # STI-based classes
    class ProcessShard < Shard; end
    class ThreadShard < Shard; end
  end
end
