require 'uuidtools'

class RFlow
  class Configuration
    # Mixin for any {ConfigurationItem} that has a UUID key.
    # Sets +primary_key+ column to be +uuid+ and initializes the
    # UUID on creation.
    # @!visibility private
    module UUIDKeyed
      # @!visibility private
      def self.included(base)
        base.class_eval do
          self.primary_key = 'uuid'
          before_create :generate_uuid

          def generate_uuid
            self.uuid = UUIDTools::UUID.random_create.to_s
          end
        end
      end
    end
  end
end
