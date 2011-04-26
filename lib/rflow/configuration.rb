require 'rflow/configuration/setting'

class RFlow
  class Configuration
    attr_accessor :config_database_path

    attr_accessor :settings
    attr_accessor :components
    
    def initialize(config_database_path, config_file_path=nil)
      self.config_database_path = config_database_path

      ActiveRecord::Base.logger = RFlow.logger
      ActiveRecord::Base.establish_connection(:adapter => "sqlite3",
                                              :database  => config_database_path)

      migrations_directory_path = File.join(File.dirname(__FILE__), 'migrations')

      RFlow.logger.info "Applying default migrations to config database #{config_database_path}"
      ActiveRecord::Migrator.migrate migrations_directory_path

      # TODO: Do this better
      # Load the config file into memory
      if config_file_path
        eval File.read(config_file_path)
      end
        
      # Clean up the in-memory configuration
      ameliorate!
      # Store the in-memory configuration to the database
      store!
      # Reload the configuration from the database
      reload!

      self
    end

    def settings;   @settings   ||= Hash.new; end
    def components; @components ||= Hash.new; end
    
    def ameliorate!
    end
    
    def store!
      settings.each do |name, value|
        # TODO: find out the right method here
        Setting.create :name => name, :value => value
      end

      components.each do 
        # TODO: Fill this in
      end
    end

    def reload!
    end
    
    # Within config file methods

    def setting(name, value)
      settings[name] = value
    end

    def component
    end
  end
end
