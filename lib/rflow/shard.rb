class RFlow

  # An object implementation shared between two processes. The parent
  # process will instantiate, configure, and run! a shard, at which
  # point the parent will have access to the shard object and be able
  # to monitor the underlying processes. The child implementation,
  # running in a separate process, will not return from run!, but
  # start an Eventmachine reactor, connect the components, and not
  # return
  class Shard

    attr_reader :instance_uuid, :name, :count
    attr_reader :pids
    attr_accessor :components
    attr_reader :configuration
    attr_reader :logger


    def initialize(uuid, name='UNNAMED', count=1)
      @instance_uuid = uuid
      @name = name
      @count = 1
      @components = Hash.new
      @configuration = RFlow.configuration.shard(instance_uuid)
      @logger = RFlow.logger

      # instantiate/confiure everything
      instantiate_components!
      configure_component_ports!
      configure_component_connections!
      configure_components!

      # At this point, each component should have their entire
      # configuration for the component-specific stuff and all the
      # connections and be ready to be connected to the others and start
      # running
    end


    def run!
      logger.info "Running shard '#{name}' (#{instance_uuid}) with #{count} workers"
      @pids = count.times.map do |i|
        logger.debug "Shard '#{name}' (#{instance_uuid}) forking worker #{i+1} of #{count}"
        # TODO: refactor this to use Process.spawn and add a
        # command-line application to start up a specific shard. Moar
        # portable across OSes.
        pid = Process.fork do
          $0 += " #{name}-#{i+1}"
          logger.debug "Shard '#{name}' (#{instance_uuid}) worker #{i+1} started"
          EM.run do
            connect_components!

            components.each do |component_uuid, component|
              RFlow.logger.debug "Shard '#{name}' #{component.to_s}"
            end

            run_components!
          end
        end

        logger.debug "Shard '#{name}' (#{instance_uuid}) worker #{i+1} of #{count} running with pid #{pid}"
        pid
      end

      logger.debug "Shard '#{name}' (#{instance_uuid}) #{count} workers running with pids #{@pids.join(', ')}"
      @pids
    end

    # Iterate through each component config in the configuration
    # database and attempt to instantiate each one, storing the
    # resulting instantiated components in the 'components' class
    # instance attribute. This assumes that the specification of a
    # component is a fully qualified Ruby class that has already been
    # loaded. It will first attempt to find subclasses of
    # RFlow::Component (in the available_components hash) and then
    # attempt to constantize the specification into a different class.
    # Future releases will support external (i.e. non-managed
    # components), but the current stuff only supports Ruby classes
    def instantiate_components!
      logger.info "Shard '#{name}' instantiating components"
      configuration.components.each do |component_config|
        if component_config.managed?
          logger.debug "Instantiating component '#{component_config.name}' as '#{component_config.specification}' (#{component_config.uuid}) in shard '#{name}' (#{instance_uuid})"
          begin
            logger.debug RFlow.configuration.available_components.inspect
            instantiated_component = if RFlow.configuration.available_components.include? component_config.specification
                                       logger.debug "Component found in configuration.available_components['#{component_config.specification}']"
                                       RFlow.configuration.available_components[component_config.specification].new(component_config.uuid, component_config.name)
                                     else
                                       logger.debug "Component not found in configuration.available_components, constantizing component '#{component_config.specification}'"
                                       component_config.specification.constantize.new(component_config.uuid, component_config.name)
                                     end

            components[component_config.uuid] = instantiated_component

          rescue NameError => e
            error_message = "Could not instantiate component '#{component_config.name}' as '#{component_config.specification}' (#{component_config.uuid}): the class '#{component_config.specification}' was not found"
            logger.error error_message
            raise RuntimeError, error_message
          rescue Exception => e
            error_message = "Could not instantiate component '#{component_config.name}' as '#{component_config.specification}' (#{component_config.uuid}): #{e.class} #{e.message}"
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
    # component its soon-to-be connected port names and UUIDs. TODO:
    # put this into the component initialization
    def configure_component_ports!
      # Send the port configuration to each component
      logger.info "Shard '#{name}' configuring component ports and assigning UUIDs to port names"
      components.each do |component_instance_uuid, component|
        logger.debug "Shard '#{name}' configuring ports for component '#{component.name}' (#{component.instance_uuid})"
        component_config = RFlow.configuration.component(component.instance_uuid)
        component_config.input_ports.each do |input_port_config|
          logger.debug "Shard '#{name}' configuring component '#{component.name}' (#{component.instance_uuid}) with input port '#{input_port_config.name}' (#{input_port_config.uuid})"
          component.configure_input_port!(input_port_config.name, input_port_config.uuid)
        end
        component_config.output_ports.each do |output_port_config|
          logger.debug "Shard '#{name}' configuring component '#{component.name}' (#{component.instance_uuid}) with output port '#{output_port_config.name}' (#{output_port_config.uuid})"
          component.configure_output_port!(output_port_config.name, output_port_config.uuid)
        end
      end
    end


    # Iterate through the instantiated components and send each
    # component the information necessary to configure a connection on
    # a specific port, specifically the port UUID, port key, type of
    # connection, uuid of connection, and a configuration specific to
    # the connection type. TODO: roll this into the component
    # initialization.
    def configure_component_connections!
      logger.info "Shard '#{name}' configuring component port connections"
      components.each do |component_instance_uuid, component|
        component_config = RFlow.configuration.component(component.instance_uuid)

        logger.debug "Shard '#{name}' configuring input connections for component '#{component.name}' (#{component.instance_uuid})"
        component_config.input_ports.each do |input_port_config|
          input_port_config.input_connections.each do |input_connection_config|
            logger.debug "Shard '#{name}' configuring input port '#{input_port_config.name}' (#{input_port_config.uuid}) key '#{input_connection_config.input_port_key}' with #{input_connection_config.type.to_s} connection '#{input_connection_config.name}' (#{input_connection_config.uuid})"
            component.configure_connection!(input_port_config.uuid, input_connection_config.input_port_key,
                                            input_connection_config.type, input_connection_config.uuid, input_connection_config.name, input_connection_config.options)
          end
        end

        logger.debug "Shard '#{name} configuring output connections for '#{component.name}' (#{component.instance_uuid})"
        component_config.output_ports.each do |output_port_config|
          output_port_config.output_connections.each do |output_connection_config|
            logger.debug "Shard '#{name}' configuring output port '#{output_port_config.name}' (#{output_port_config.uuid}) key '#{output_connection_config.output_port_key}' with #{output_connection_config.type.to_s} connection '#{output_connection_config.name}' (#{output_connection_config.uuid})"
            component.configure_connection!(output_port_config.uuid, output_connection_config.output_port_key,
                                            output_connection_config.type, output_connection_config.uuid, output_connection_config.name, output_connection_config.options)
          end
        end
      end
    end


    # Send the component-specific configuration to the component. Like
    # the above, put into the component initialization
    def configure_components!
      logger.info "Shard '#{name}' configuring components with component-specific configurations"
      components.each do |component_uuid, component|
        component_config = RFlow.configuration.component(component.instance_uuid)
        logger.debug "Shard '#{name}' configuring component '#{component.name}' (#{component.instance_uuid})"
        component.configure!(component_config.options)
      end
    end


    # Stuff after here happens withing the EM reactor

    # Send a command to each component to tell them to connect their
    # ports via their connections
    def connect_components!
      logger.info "Shard '#{name}' connecting components"
      components.each do |component_uuid, component|
        logger.debug "Shard '#{name}' connecting component '#{component.name}' (#{component.instance_uuid})"
        component.connect!
      end
    end

    # Start each component running
    def run_components!
      logger.info "Shard '#{name}' running components"
      components.each do |component_uuid, component|
        logger.debug "Shard '#{name}' running component '#{component.name}' (#{component.instance_uuid})"
        component.run!
      end
    end


  end
end
