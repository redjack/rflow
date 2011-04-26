require "rubygems"
require "bundler/setup"

require 'log4r'
require 'sqlite3'
require 'active_record'

require 'rflow/configuration'

include Log4r

class RFlow
  class << self
    attr_accessor :config_database_path
    attr_accessor :logger
    attr_accessor :configuration
  end

  def self.initialize_config_database(config_database_path, config_file_path)
    self.configuration = Configuration.new(config_database_path, config_file_path)
  end

  def self.run(config_database_path)
    self.configuration = Configuration.new config_database_path
    # Specify Logger
    # Validate the config database accessibility
    # Merge configuration defaults
    # Validate the directories
    # Resolve any missing UUIDs
  end
  
end # class RFlow
