class RFlow

  # An object implementation shared between two processes. The parent
  # process will instantiate, configure, and run! a shard, at which
  # point the parent will have access to the shard object and be able
  # to monitor the underlying processes. The child implementation,
  # running in a separate process, will not return from run!, but
  # start an Eventmachine reactor, connect the components, and not
  # return
  class Shard

    attr_reader :config, :uuid, :name, :count
    attr_reader :pids
    attr_accessor :components
    attr_reader :logger


    def initialize(config)
      @config = config
      @uuid = config.uuid
      @name = config.name
      @count = config.count
      @components = Hash.new
      @logger = RFlow.logger

      # instantiate/configure everything
      instantiate_components!

      # At this point, each component should have their entire
      # configuration for the component-specific stuff and all the
      # connections and be ready to be connected to the others and start
      # running
    end


    def run!
      logger.info "Running shard '#{name}' (#{uuid}) with #{count} workers"
      @pids = count.times.map do |i|
        logger.debug "Shard '#{name}' (#{uuid}) forking worker #{i+1} of #{count}"
        # TODO: refactor this to use Process.spawn and add a
        # command-line application to start up a specific shard. Moar
        # portable across OSes.
        pid = Process.fork do
          $0 += " #{name}-#{i+1}"
          logger.debug "Shard '#{name}' (#{uuid}) worker #{i+1} started"
          EM.run do
            connect_components!
            run_components!
          end
        end

        logger.debug "Shard '#{name}' (#{uuid}) worker #{i+1} of #{count} running with pid #{pid}"
        pid
      end

      logger.debug "Shard '#{name}' (#{uuid}) #{count} workers running with pids #{@pids.join(', ')}"
      @pids
    end


    def instantiate_components!
      logger.info "Shard '#{name}' instantiating components"
      config.components.each do |component_config|
        components[component_config.uuid] = Component.build(component_config)
      end
    end

    # Stuff after here happens withing the EM reactor

    # Send a command to each component to tell them to connect their
    # ports via their connections
    def connect_components!
      logger.info "Shard '#{name}' connecting components"
      components.each do |component_uuid, component|
        logger.debug "Shard '#{name}' connecting component '#{component.name}' (#{component.uuid})"
        component.connect!
      end
    end

    # Start each component running
    def run_components!
      logger.info "Shard '#{name}' running components"
      components.each do |component_uuid, component|
        logger.debug "Shard '#{name}' running component '#{component.name}' (#{component.uuid})"
        component.run!
      end
    end


  end
end
