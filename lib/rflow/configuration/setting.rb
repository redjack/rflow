require 'active_record'
require 'rflow/configuration/uuid_keyed'

class RFlow
  class Configuration
    # Represents a setting in the SQLite database.
    class Setting < ConfigurationItem
      include ActiveModel::Validations

      self.primary_key = 'name'

      # Default settings.
      DEFAULTS = {
        'rflow.application_name'           => 'rflow',
        'rflow.application_directory_path' => '.',
        'rflow.pid_directory_path'         => 'run', # relative to rflow.application_directory_path
        'rflow.log_directory_path'         => 'log', # relative to rflow.application_directory_path
        'rflow.log_file_path' => lambda {File.join(Setting['rflow.log_directory_path'], Setting['rflow.application_name'] + '.log')},
        'rflow.pid_file_path' => lambda {File.join(Setting['rflow.pid_directory_path'], Setting['rflow.application_name'] + '.pid')},
        'rflow.log_level' => 'INFO',
      }

      private
      DIRECTORY_PATHS = [
        'rflow.application_directory_path',
        'rflow.pid_directory_path',
        'rflow.log_directory_path',
      ]

      FILE_PATHS = [
        'rflow.log_file_path',
        'rflow.pid_file_path',
      ]

      # TODO: fix these validations, as they run without the
      # application directory path context for subdirectories
      #validate :valid_directory_path?, :if => :directory_path?
      #validate :valid_writable_path?, :if => :directory_path?

      # TODO: Think about making this a regex check to pull in other,
      # externally-defined settings
      def directory_path?
        DIRECTORY_PATHS.include? self.name
      end

      def valid_directory_path?
        unless File.directory? self.value
          errors.add :value, "setting '#{self.name}' is not a directory ('#{File.expand_path self.value}')"
        end
      end

      def valid_writable_path?
        unless File.writable? self.value
          errors.add :value, "setting '#{self.name}' is not writable ('#{File.expand_path self.value}')"
        end
      end

      public
      # Look up a {Setting} by name from the SQLite database.
      # @return [Setting]
      def self.[](name)
        Setting.find(name).value rescue nil
      end
    end
  end
end
