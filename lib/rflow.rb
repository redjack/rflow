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

  class Error < StandardError; end

  class << self
    attr_accessor :config_database_path
    attr_accessor :logger
    attr_accessor :configuration
    attr_accessor :master
  end


  def self.trap_signals
    # Gracefully shutdown on termination signals
    ['SIGTERM', 'SIGINT', 'SIGQUIT'].each do |signal|
      Signal.trap signal do
        logger.warn "Termination signal (#{signal}) received, shutting down"
        shutdown
      end
    end

    # Reload on HUP
    ['SIGHUP'].each do |signal|
      Signal.trap signal do
        logger.warn "Reload signal (#{signal}) received, reloading"
        reload
      end
    end

    # Ignore terminal signals
    # TODO: Make sure this is valid for non-daemon (foreground) process
    ['SIGTSTP', 'SIGTTOU', 'SIGTTIN'].each do |signal|
      Signal.trap signal do
        logger.warn "Terminal signal (#{signal}) received, ignoring"
      end
    end

    # Reopen logs on USR1
    ['SIGUSR1'].each do |signal|
      Signal.trap signal do
        logger.warn "Reopen logs signal (#{signal}) received, reopening #{configuration['rflow.log_file_path']}"
        reopen_log_file
      end
    end

    # Toggle log level on USR2
    ['SIGUSR2'].each do |signal|
      Signal.trap signal do
        logger.warn "Toggle log level signal (#{signal}) received, toggling"
        toggle_log_level
      end
    end

    # TODO: Manage SIGCHLD when spawning other processes
  end


  def self.run(config_database_path=nil, daemonize=nil)
    self.configuration = Configuration.new(config_database_path)

    if config_database_path
      # First change to the config database directory, which might hold
      # relative paths for the other files/directories, such as the
      # application_directory_path
      Dir.chdir File.dirname(config_database_path)
    end

    # Bail unless you have some of the basic information.  TODO:
    # rethink this when things get more dynamic
    unless configuration['rflow.application_directory_path']
      error_message = "Empty configuration database!  Use a view/controller (such as the RubyDSL) to create a configuration"
      RFlow.logger.error "Empty configuration database!  Use a view/controller (such as the RubyDSL) to create a configuration"
      raise ArgumentError, error_message
    end

    Dir.chdir configuration['rflow.application_directory_path']

    self.logger = RFlow::Logger.new(configuration, !daemonize)
    @master = Master.new(configuration)

    # Daemonize
    trap_signals
    master.daemonize! if daemonize
    master.run # Runs EM and doesn't return

    # Should never get here
    logger.warn "going down"
  rescue SystemExit => e
    # Do nothing, just prevent a normal exit from causing an unsightly
    # error in the logs
    logger.info "Exiting: #{e.message}"
  rescue Exception => e
    logger.fatal "Exception caught: #{e.class} - #{e.message}\n#{e.backtrace.join "\n"}"
    exit 1
  end


end # class RFlow
