require 'rubygems'
require 'bundler/setup'
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

    RFlow.logger = RFlow::Logger.new({})
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
      raise ArgumentError, 'Empty configuration database!  Use a view/controller (such as the RubyDSL) to create a configuration'
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
    logger.reconfigure(configuration, include_stdout)
  end

  def self.start_master_node
    RFlow.logger.info "#{configuration['rflow.application_name']} starting"
    @master = Master.new(configuration)
    master.daemonize! if @daemonize
    master.run! # blocks until EventMachine stops
  end

  # Nice pretty wrapper method to help reduce direct dependencies on EM
  def self.next_tick(pr = nil, &block)
    EM.next_tick(pr, &block)
  end

  def self.default_error_callback(error)
    RFlow.logger.error "Unhandled error on worker thread: #{error.class}: #{error.message}, because: #{error.backtrace}"
  end

  # Wrapped version of EM.defer that also fixes logging, releases AR
  # connections, and catches exceptions that would otherwise propagate to the
  # main thread magically
  def self.defer(op = nil, callback = nil, errback = nil, &blk)
    context = RFlow.logger.clone_logging_context
    EM.defer(nil, callback, errback || method(:default_error_callback)) do
      begin
        RFlow.logger.apply_logging_context context
        (op || blk).call
      ensure
        ActiveRecord::Base.connection_pool.release_connection
      end
    end
  end

  # This ought to be in EM, but we'll put it here instead of monkey-patching
  def self.next_tick_and_wait
    mutex = Mutex.new
    condition = ConditionVariable.new

    mutex.synchronize do # while locked...
      RFlow.next_tick do # schedule a job that will...
        mutex.synchronize do # grab the lock
          begin
            yield # do its thing...
            condition.signal # then wake us up when it's done...
          rescue
            condition.signal # even if the thing fails
            raise
          end
        end
      end
      condition.wait(mutex) # drop the mutex to allow the job to run
    end
  end
end
