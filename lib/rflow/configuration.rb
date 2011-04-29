require 'rflow/configuration/setting'

class RFlow
  class Configuration
    attr_accessor :config_database_path
    attr_accessor :cached_settings
    
    def initialize(config_database_path, config_file_path=nil)
      self.config_database_path = config_database_path

      ActiveRecord::Base.logger = RFlow.logger
      ActiveRecord::Base.establish_connection(:adapter => "sqlite3",
                                              :database  => self.config_database_path)

      migrations_directory_path = File.join(File.dirname(__FILE__), 'configuration', 'migrations')

      RFlow.logger.info "Applying default migrations to config database #{self.config_database_path}"
      ActiveRecord::Migrator.migrate migrations_directory_path

      # Load any stored config into memory
      RFlow.logger.debug "Loading config database '#{self.config_database_path}'"
      reload!
      
      # TODO: Do this better, need error handling, what happens to
      # stored data?
      # Load the config file into memory
      RFlow.logger.debug "Loading config file '#{config_file_path}'"
      if config_file_path
        eval File.read(config_file_path)
      end

      # Clean-up the in-memory configuration
      RFlow.logger.debug "Cleaning up config"
      ameliorate!
      # Perform some validations of the config
      RFlow.logger.debug "Validating config"
      validate!
      # Store the in-memory configuration to the database
      RFlow.logger.debug "Storing config"
      store!
      # Reload the configuration from the database
      RFlow.logger.debug "Reloading config"
      reload!

      self
    end

    def cached_settings; @cached_settings ||= Hash.new; end

    def [](setting_name)
      cached_settings[setting_name].value if cached_settings.include?(setting_name)
    end

    def []=(setting_name, setting_value)
      RFlow.logger.debug "Setting #{setting_name} to #{setting_value}"
      if cached_settings.include?(setting_name)
        cached_settings[setting_name].value = setting_value
      else
        cached_settings[setting_name] = Setting.new :name => setting_name, :value => setting_value
      end
      cached_settings[setting_name].value
    end
      
    def ameliorate!
      # Set the defaults
      Setting::DEFAULTS.each do |name, default_value_proc|
        cached_settings[name] ||= Setting.new :name => name, :value => default_value_proc.call(self)
      end

      # Do anything else necessary to clean-up/expand config
    end

    def validate!
      # Run the standard ActiveRecord validations
      cached_settings.each do |name, model|
        unless model.valid?
          error_message = "Invalid setting '#{name}' = '#{model.value}': #{model.errors.inspect}"
          RFlow.logger.error error_message
          raise Setting::Invalid, error_message
        end
      end
    end
    
    def store!
      cached_settings.each do |name, model|
        # TODO: error handling
        model.save
      end
    end

    def reload!
      # TODO: Look at this for correctness
      cached_settings.clear
      Setting.all.each do |setting_model|
        RFlow.logger.debug "Loading #{setting_model.name} as #{setting_model.value}"
        cached_settings[setting_model.name] = setting_model
      end

      # TODO: Load other configs
    end

    # Within config file methods
    # TODO: better error handling and definition of config file only
    # method, as it won't persist to the DB without a later call to
    # store!
    def setting(name, value)
      self[name] = value
    end

  end
end
