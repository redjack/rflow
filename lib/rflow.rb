require "rubygems"
require "bundler/setup"
require 'time'
require 'active_record'
require 'eventmachine'
require 'sqlite3'
require 'rflow/configuration'
require 'rflow/master'
require 'rflow/message'
require 'rflow/components'
require 'rflow/connections'
require 'rflow/logger'

class RFlow
  include Log4r

  class << self
    attr_accessor :logger
    attr_accessor :configuration
    attr_accessor :master
  end

  def self.run(config_database_path = nil, daemonize = nil)
    self.configuration = Configuration.new(config_database_path)

    if config_database_path
      # First change to the config database directory, which might hold
      # relative paths for the other files/directories, such as the
      # application_directory_path
      Dir.chdir File.dirname(config_database_path)
    end

    # Bail unless you have some of the basic information.
    # TODO: rethink this when things get more dynamic
    unless configuration['rflow.application_directory_path']
      raise ArgumentError, "Empty configuration database!  Use a view/controller (such as the RubyDSL) to create a configuration"
    end

    Dir.chdir configuration['rflow.application_directory_path']

    self.logger = RFlow::Logger.new(configuration, !daemonize)
    @master = Master.new(configuration)

    master.daemonize! if daemonize
    master.run # Runs EM and doesn't return
  rescue SystemExit => e
    # Do nothing, just prevent a normal exit from causing an unsightly
    # error in the logs
  end
end
