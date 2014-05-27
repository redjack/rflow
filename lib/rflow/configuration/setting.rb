require 'active_record'
require 'rflow/configuration/uuid_keyed'

class RFlow
  class Configuration
    class Setting < ConfigDB
      class SettingInvalid < StandardError; end

      include ActiveModel::Validations

      self.primary_key = 'name'

      attr_accessible :name, :value

      DEFAULTS = {
        'rflow.application_name' => 'rflow',
        'rflow.application_directory_path' => '.',
        'rflow.pid_directory_path'         => 'run', #lambda {File.join(Setting['rflow.application_directory_path'], 'run')},
        'rflow.log_directory_path'         => 'log', #lambda {File.join(Setting['rflow.application_directory_path'], 'log')},
        'rflow.log_file_path' => lambda {File.join(Setting['rflow.log_directory_path'], Setting['rflow.application_name'] + '.log')},
        'rflow.pid_file_path' => lambda {File.join(Setting['rflow.pid_directory_path'], Setting['rflow.application_name'] + '.pid')},
        'rflow.log_level' => 'INFO',
      }

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
      #application directory path context for subdirectories
      #validate :valid_directory_path, :if => :directory_path?
      #validate :valid_writable_path, :if => :directory_path?

      # TODO: Think about making this a regex check to pull in other,
      # externally-defined settings
      def directory_path?
        DIRECTORY_PATHS.include? self.name
      end

      def valid_directory_path
        unless File.directory? self.value
          errors.add :value, "setting '#{self.name}' is not a directory ('#{File.expand_path self.value}')"
        end
      end

      def valid_writable_path
        unless File.writable? self.value
          errors.add :value, "setting '#{self.name}' is not writable ('#{File.expand_path self.value}')"
        end
      end

      def self.[](setting_name)
        Setting.find(setting_name).value rescue nil
      end
    end
  end
end
