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
    attr_reader :configuration, :master
  end

  def self.run!(config_database_path = nil, daemonize = false)
    @config_database_path = config_database_path
    @daemonize = daemonize

    establish_configuration
    chdir_application_directory
    setup_logger
    start_master_node
  rescue SystemExit => e
    # Do nothing, just prevent a normal exit from causing an unsightly
    # error in the logs
  end

  private
  def self.establish_configuration
    @configuration = Configuration.new(@config_database_path)
    unless configuration['rflow.application_directory_path']
      raise ArgumentError, "Empty configuration database!  Use a view/controller (such as the RubyDSL) to create a configuration"
    end
  end

  def self.chdir_application_directory
    # First change to the config db directory, which might hold
    # relative paths for the other files/directories
    Dir.chdir(File.dirname(@config_database_path)) if @config_database_path
    Dir.chdir configuration['rflow.application_directory_path']
  end

  def self.setup_logger
    include_stdout = !@daemonize
    self.logger = RFlow::Logger.new(configuration, include_stdout)
  end

  def self.start_master_node
    RFlow.logger.info "#{configuration['rflow.application_name']} starting"
    @master = Master.new(configuration)
    master.daemonize! if @daemonize
    master.run! # blocks until EventMachine stops
  end
end
