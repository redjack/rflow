require 'rflow/child_process'

class RFlow
  # An object implementation shared between two processes. The parent
  # process will instantiate, configure, and run! a shard, at which
  # point the parent will have access to the shard object and be able
  # to monitor the underlying processes. The child implementation,
  # running in a separate process, will not return from spawn!, but
  # start an EventMachine reactor.
  class Shard
    class Worker < ChildProcess
      attr_reader :shard, :index

      def initialize(shard, index = 1)
        super("#{shard.name}-#{index}", 'Worker')
        @shard = shard
        @index = index

        # build at initialize time to fail fast
        @components = shard.config.components.map {|config| Component.build(self, config) }
      end

      def run_process
        EM.run do
          begin
            # TODO: Monitor the master
            configure_components!
            connect_components!
            # TODO: need to do proper node synchronization for ZMQ to remove sleep
            sleep 1
            run_components!
          rescue Exception => e
            RFlow.logger.error "Error in worker, shutting down: #{e.class.name}: #{e.message}, because: #{e.backtrace.inspect}"
          end
        end

        RFlow.logger.info "Shutting down worker after EM stopped"
      end

      def configure_components!
        RFlow.logger.debug "Configuring components"
        @components.zip(shard.config.components.map(&:options)).each do |(component, config)|
          RFlow.logger.debug "Configuring component '#{component.name}' (#{component.uuid})"
          component.configure! config
        end
      end

      # Connect all inputs before all outputs, so connection types that require a 'server'
      # to be established before a 'client' can connect can get themselves ready.
      def connect_components!
        RFlow.logger.debug "Connecting components"
        @components.each do |component|
          RFlow.logger.debug "Connecting inputs for component '#{component.name}' (#{component.uuid})"
          component.connect_inputs!
        end
        @components.each do |component|
          RFlow.logger.debug "Connecting outputs for component '#{component.name}' (#{component.uuid})"
          component.connect_outputs!
        end
      end

      def run_components!
        RFlow.logger.debug "Running components"
        @components.each do |component|
          RFlow.logger.debug "Running component '#{component.name}' (#{component.uuid})"
          component.run!
        end
      end

      def shutdown!(signal)
        EM.stop_event_loop
        super
      end
    end

    attr_reader :config, :name, :count, :workers

    def initialize(config)
      @config = config
      @uuid = config.uuid
      @name = config.name
      @count = config.count
      @workers = count.times.map {|i| Worker.new(self, i+1) }
    end

    def run!
      RFlow.logger.debug "Running shard #{name} with #{count} workers"
      workers.each(&:spawn!)

      RFlow.logger.debug "#{count} workers started for #{name}: #{workers.map { |w| "#{w.name} (#{w.pid})" }.join(", ")}"
      workers
    end
  end
end
