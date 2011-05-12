require "rubygems"
require "bundler/setup"

require 'log4r'
require 'sqlite3'
require 'active_record'

require 'eventmachine'

require 'rflow/configuration'
require 'rflow/component'
require 'rflow/message'

require 'rflow/connections'

include Log4r

class RFlow
  class Error < StandardError; end

  LOG_PATTERN_FORMAT = '%l [%d] %c (%p) - %M'
  DATE_PATTERN_FORMAT = '%Y-%m-%dT%H:%M:%S.%9N %z'
  LOG_PATTERN_FORMATTER = PatternFormatter.new :pattern => RFlow::LOG_PATTERN_FORMAT, :date_pattern => DATE_PATTERN_FORMAT
  
  class << self
    attr_accessor :config_database_path
    attr_accessor :logger
    attr_accessor :configuration
    attr_accessor :components
  end
  
#   def self.initialize_config_database(config_database_path, config_file_path=nil)
#     # To handle relative paths in the config (all relative paths are
#     # relative to the config database
#     Dir.chdir File.dirname(config_database_path)
#     Configuration.new(File.basename(config_database_path), config_file_path)
#   end

  def self.initialize_logger(log_file_path, log_level='INFO')
    rflow_logger = Logger.new 'rflow.log'
    begin
      rflow_logger.add FileOutputter.new('rflow.log_file', :filename => log_file_path, :formatter => LOG_PATTERN_FORMATTER)
    rescue Exception => e
      RFlow.logger.error "Log file '#{log_file_path}' problem: #{e.message}"
      raise Error, "Log file '#{log_file_path}' problem: #{e.message}"
    end

    rflow_logger.level = LNAMES.index log_level
    
    RFlow.logger.info "Transitioning to running log file #{log_file_path} at level #{log_level}"
    RFlow.logger = rflow_logger
  end

  def self.reopen_log_file
    # TODO: Make this less of a hack, although Log4r doesn't support
    # it, so it might be permanent
    log_file = Outputter['rflow.log_file'].instance_variable_get(:@out)
    File.open(log_file.path, 'a') { |tmp_log_file| log_file.reopen(tmp_log_file) }
  end

  def self.toggle_log_level
    original_log_level = LNAMES[logger.level]
    new_log_level = (original_log_level == 'DEBUG' ? configuration['rflow.log_level'] : 'DEBUG')
    logger.warn "Changing log level from #{original_log_level} to #{new_log_level}"
    logger.level = LNAMES.index new_log_level
p  end
  
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

  
  # returns a PID if a given path contains a non-stale PID file,
  # nil otherwise.
  def self.running_pid_file_path?(pid_file_path)
    return nil unless File.exist? pid_file_path
    running_pid? File.read(pid_file_path).to_i
  end
  
  def self.running_pid?(pid)
    return if pid <= 0
    Process.kill(0, pid)
    pid
  rescue Errno::ESRCH, Errno::ENOENT
    nil
  end

  # unlinks a PID file at given if it contains the current PID still
  # potentially racy without locking the directory (which is
  # non-portable and may interact badly with other programs), but the
  # window for hitting the race condition is small
  def self.remove_pid_file(pid_file_path)
    (File.read(pid_file_path).to_i == $$ and File.unlink(pid_file_path)) rescue nil
    logger.debug "Removed PID (#$$) file '#{File.expand_path pid_file_path}'"
  end
  
  # TODO: Handle multiple instances and existing PID file
  def self.write_pid_file(pid_file_path)
    pid = running_pid_file_path?(pid_file_path)
    if pid && pid == $$
      logger.warn "Already running (#{pid.to_s}), not writing PID to file '#{File.expand_path pid_file_path}'"
      return pid_file_path
    elsif pid
      error_message = "Already running (#{pid.to_s}), possibly stale PID file '#{File.expand_path pid_file_path}'"
      logger.error error_message
      raise ArgumentError, error_message
    elsif File.exist? pid_file_path
      logger.warn "Found stale PID file '#{File.expand_path pid_file_path}', removing"
      remove_pid_file pid_file_path
    end

    logger.debug "Writing PID (#$$) file '#{File.expand_path pid_file_path}'"
    pid_fp = begin
               tmp_pid_file_path = File.join(File.dirname(pid_file_path), ".#{File.basename(pid_file_path)}")
               File.open(tmp_pid_file_path, File::RDWR|File::CREAT|File::EXCL, 0644)
             rescue Errno::EEXIST
               retry
             end
    pid_fp.syswrite("#$$\n")
    File.rename(pid_fp.path, pid_file_path)
    pid_fp.close

    pid_file_path
  end
  
  # TODO: Refactor this to be cleaner
  def self.daemonize!(application_name, pid_file_path)
    logger.info "#{application_name} daemonizing"

    # TODO: Drop privileges

    # Daemonize, but don't chdir or close outputs
    Process.daemon(true, true)

    # Set the process name
    $0 = application_name if application_name

    # Write the PID file
    write_pid_file pid_file_path

    # Close standard IO
    $stdout.sync = $stderr.sync = true
    $stdin.binmode; $stdout.binmode; $stderr.binmode
    begin; $stdin.reopen  "/dev/null"; rescue ::Exception; end  
    begin; $stdout.reopen "/dev/null"; rescue ::Exception; end
    begin; $stderr.reopen "/dev/null"; rescue ::Exception; end

    $$
  end


  # Iterate through each component config in the configuration
  # database and attempt to instantiate each one, storing the
  # resulting instantiated components in the 'components' class
  # instance attribute.  This assumes that the specification of a
  # component is a fully qualified Ruby class that has already been
  # loaded.  Future releases will support external (i.e. non-managed
  # components), but the current stuff only supports Ruby classes
  def self.instantiate_components!
    logger.info "Instantiating Components"
    self.components = Hash.new
    configuration.components.each do |component_config|
      if component_config.managed?
        logger.info "Instantiating component '#{component_config.name}' as '#{component_config.specification}' (#{component_config.uuid})"
        begin
          instantiated_component = component_config.specification.constantize.new(component_config.uuid, component_config.name)
          components[component_config.uuid] = instantiated_component
        rescue Exception => e
          error_message = "Could not instantiate component '#{component_config.name}' as '#{component_config.specification}' (#{component_config.uuid}): #{e.message}"
          logger.error error_message
          raise RuntimeError, error_message
        end
      else
        error_message = "Non-managed components not yet implemented for component '#{component_config.name}' as '#{component_config.specification}' (#{component_config.uuid})"
        logger.error error_message
        raise NotImplementedError, error_message
      end
    end
  end


  # Iterate through the instantiated components and send each
  # component its soon-to-be connected port names and UUIDs
  def self.configure_component_ports!
    # Send the port configuration to each component
    logger.info "Configuring component ports and assigning UUIDs to port names"
    components.each do |component_instance_uuid, component|
      component_config = configuration.component(component.instance_uuid)
      component_config.input_ports.each do |input_port_config|
        component.configure_input_port!(input_port_config.name, input_port_config.uuid)
      end
      component_config.output_ports.each do |output_port_config|
        component.configure_output_port!(output_port_config.name, output_port_config.uuid)
      end
    end
  end


  # Iterate through the instantiated components and send each
  # component the information necessary to configure a connection on a
  # specific port, specifically the port UUID, port key, type of connection, uuid
  # of connection, and a configuration specific to the connection type
  def self.configure_component_connections!
    logger.info "Configuring component connections"
    components.each do |component_instance_uuid, component|
      component_config = configuration.component(component.instance_uuid)

      logger.debug "Configuring input connections for '#{component.name}' (#{component.instance_uuid})"
      component_config.input_ports.each do |input_port_config|
        input_port_config.input_connections.each do |input_connection_config|
          logger.debug "Configuring input port '#{input_port_config.name}' (#{input_port_config.uuid}) key '#{input_connection_config.input_port_key}' with #{input_connection_config.type.to_s} connection '#{input_connection_config.name}' (#{input_connection_config.uuid})"
          component.configure_connection!(input_port_config.uuid, input_connection_config.input_port_key,
                                          input_connection_config.type, input_connection_config.uuid, input_connection_config.options)
        end
      end

      logger.debug "Configuring output connections for '#{component.name}' (#{component.instance_uuid})"
      component_config.output_ports.each do |output_port_config|
        output_port_config.output_connections.each do |output_connection_config|
          logger.debug "Configuring output port '#{output_port_config.name}' (#{output_port_config.uuid}) key '#{output_connection_config.output_port_key}' with #{output_connection_config.type.to_s} connection '#{output_connection_config.name}' (#{output_connection_config.uuid})"
          component.configure_connection!(output_port_config.uuid, output_connection_config.output_port_key,
                                          output_connection_config.type, output_connection_config.uuid, output_connection_config.options)
        end
      end
    end
  end
  
  
  # Send the component-specific configuration to the component
  def self.configure_components!
    logger.info "Configuring components with component-specific configurations"
    components.each do |component_uuid, component|
      component_config = configuration.component(component.instance_uuid)
      logger.debug "Configuring component '#{component.name}' (#{component.instance_uuid})"
      component.configure!(component_config.options)
    end
  end

  # Send a command to each component to tell them to connect their
  # ports via their connections 
  def self.connect_components!
    logger.info "Connecting components"
    components.each do |component_uuid, component|
      logger.debug "Connecting component '#{component.name}' (#{component.instance_uuid})"
      component.connect!
    end
  end

  # Start each component running
  def self.run_components!
    logger.info "Running components"
    components.each do |component_uuid, component|
      logger.debug "Running component '#{component.name}' (#{component.instance_uuid})"
      component.run!
    end
  end
  
  def self.run(config_database_path, daemonize=nil)
    self.configuration = Configuration.new(config_database_path)
    initialize_logger(configuration['rflow.log_file_path'], configuration['rflow.log_level'])

    application_name = configuration['rflow.application_name']
    logger.info "#{application_name} starting"

    Dir.chdir configuration['rflow.application_directory_path']

    trap_signals

    if daemonize
      daemonize!(application_name, configuration['rflow.pid_file_path'])
    else
      # Still write the PID file for consistency
      write_pid_file configuration['rflow.pid_file_path']
    end

    logger.info "#{application_name} configured and daemonized, starting flow"
    logger.debug "Available Data Extensions: #{RFlow::Configuration.available_data_extensions.inspect}"
    logger.debug "Available Data Schemas: #{RFlow::Configuration.available_data_schemas.inspect}"
    logger.debug "Available Components: #{RFlow::Configuration.available_components.inspect}"

    # TODO: Start up a FlowManager component and connect it to the
    # management interface on all the components

    instantiate_components!
    configure_component_ports!
    configure_component_connections!
    configure_components!

    # At this point, each component should be ready to be connected to
    # the others and start running

    EM.run do 
      connect_components!
      run_components!
      # Sit back and relax
    end
    
    # Should never get here
    shutdown
    
    # TODO: Load schemas into registry
    # TODO: Load components into registry
    # TODO: Look into Parallel::ForkManager
    # TODO: Figure out how to shutdown
  rescue SystemExit => e
    # Do nothing, just prevent a normal exit from causing an unsightly
    # error in the logs
  rescue Exception => e
    logger.fatal "Exception caught: #{e.class} - #{e.message}\n#{e.backtrace.join "\n"}"
    exit 1
  end

  def self.shutdown
    logger.info "#{configuration['rflow.application_name']} shutting down"
    remove_pid_file configuration['rflow.pid_file_path']
    logger.info "#{configuration['rflow.application_name']} exiting"
    exit 0
  end

  def self.reload
    logger.info "#{configuration['rflow.application_name']} reloading"
    reload_log_file
    logger.info "#{configuration['rflow.application_name']} reloaded"
  end

end # class RFlow
