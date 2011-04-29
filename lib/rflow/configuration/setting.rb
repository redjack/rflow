require 'active_record'

class RFlow
  class Configuration
    class Setting < ActiveRecord::Base
      include ActiveModel::Validations
      
      class Invalid < StandardError; end
      
      DEFAULTS = {
        'rflow.application_name' => lambda {|config| 'rflow'},
        
        'rflow.application_directory_path' => lambda {|config| '.'},
        'rflow.pid_directory_path'         => lambda {|config| File.join(config['rflow.application_directory_path'], 'run')},
        'rflow.log_directory_path'         => lambda {|config| File.join(config['rflow.application_directory_path'], 'log')},

        'rflow.log_file_path' => lambda {|config| File.join(config['rflow.log_directory_path'], config['rflow.application_name'] + '.log') rescue nil},
        'rflow.pid_file_path' => lambda {|config| File.join(config['rflow.pid_directory_path'], config['rflow.application_name'] + '.pid') rescue nil},
        
        'log_level' => lambda {|config| 'INFO'}        
      }

      DIRECTORY_PATHS = [
                         'rflow.application_directory_path',
                         'rflow.pid_directory_path',
                         'rflow.log_directory_path',
                        ]
      FILE_PATHS = [
                    'log_file_path',
                    'pid_file_path',
                   ]
      LOG_LEVELS = ['log_level']

      # Validations
      validates_uniqueness_of :name

      validate :valid_directory_path, :if => :directory_path?
      validate :valid_writable_path, :if => :directory_path?

      # TODO: Think about making this a regex check to pull in other,
      # externally-defined settings 
      def directory_path?
        DIRECTORY_PATHS.include? self.name
      end

      def valid_directory_path
        unless File.directory? self.value
          errors.add :value, "is not a directory"
        end
      end
      
      def valid_writable_path
        unless File.writable? self.value
          errors.add :value, "is not writable"
        end
      end

    end
  end
end
