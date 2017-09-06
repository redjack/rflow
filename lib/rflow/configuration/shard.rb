require 'active_record'
require 'rflow/configuration/uuid_keyed'

class RFlow
  class Configuration
    # Represents a process shard in the SQLite database.
    class Shard < ConfigurationItem
      include UUIDKeyed
      include ActiveModel::Validations

      # Exception for when the shard is invalid.
      class ShardInvalid < StandardError; end

      # @!attribute components
      #   The {Component}s that are to run in this {Shard}.
      #   @return [Array<Component>]
      has_many :components, :primary_key => 'uuid', :foreign_key => 'shard_uuid'

      validates_uniqueness_of :name
      validates_numericality_of :count, :only_integer => true, :greater_than => 0
    end

    # Subclass of {Shard} representing a shard instantiated by a process.
    class ProcessShard < Shard; end
    # Subclass of {Shard} representing a shard instantiated by a thread.
    class ThreadShard < Shard; end
  end
end
