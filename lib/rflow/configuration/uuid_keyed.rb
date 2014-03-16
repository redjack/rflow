require 'uuidtools'

class RFlow
  class Configuration
    module UUIDKeyed
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
