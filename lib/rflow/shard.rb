class RFlow

  # An object implementation shared between two processes. The parent
  # process will instantiate, configure, and run! a shard, at which
  # point the parent will have access to the shard object and be able
  # to monitor the underlying processes. The child implementation,
  # running in a separate process, will not return from run!, but
  # start an Eventmachine reactor, connect the components, and not
  # return
  class Shard

    # An internal class that represents an instance of the running
    # shard, i.e. a process
    class Worker

      attr_accessor :shard, :index, :name, :pid
      attr_accessor :components
      attr_accessor :worker_read, :master_write

      def initialize(shard, index=1)
        @shard = shard
        @index = index
        @name  = "#{shard.name}-#{index}"

        # Set up the IPC pipes
        @worker_read, @master_write = IO.pipe
        [@worker_read, @master_write].each do |io|
          io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
        end

        @components = shard.config.components.map do |component_config|
          Component.build(component_config)
        end
      end

      def handle_signals
        ['SIGTERM', 'SIGINT', 'SIGQUIT'].each do |signal|
          Signal.trap signal do
            Thread.new { shutdown(signal) }.join
          end
        end

        ['SIGUSR1'].each do |signal|
          Signal.trap signal do
            Thread.new do
              RFlow.logger.reopen
            end.join
          end
        end

        # Toggle log level on USR2
        ['SIGUSR2'].each do |signal|
          Signal.trap signal do
            Thread.new do
              RFlow.logger.toggle_log_level
            end.join
          end
        end
      end

      # Launch another process to execute the shard. The parent
      # process retains the original worker object (with pid and IPC
      # pipe) to allow for process management
      def launch
        @pid = Process.fork do
          @master_write.close

          handle_signals

          $0 += " #{name}"
          Log4r::NDC.push name

          RFlow.logger.info "Worker started"
          EM.run do
            # TODO: Monitor the master

            connect_components!
            # TODO: need to do proper node synchronization for ZMQ to
            # remove sleep
            sleep 1
            run_components!
          end

          RFlow.logger.info "Shutting down worker after EM stopped"
        end

        @worker_read.close
        self
      end

      # Send a command to each component to tell them to connect their
      # ports via their connections
      def connect_components!
        RFlow.logger.debug "Connecting components"
        components.each do |component|
          RFlow.logger.debug "Connecting component '#{component.name}' (#{component.uuid})"
          component.connect!
        end
      end

      # Start each component running
      def run_components!
        RFlow.logger.debug "Running components"
        components.each do |component|
          RFlow.logger.debug "Running component '#{component.name}' (#{component.uuid})"
          component.run!
        end
      end
    end


    attr_reader :config, :uuid, :name, :count
    attr_accessor :workers


    def initialize(config)
      @config = config
      @uuid = config.uuid
      @name = config.name
      @count = config.count

      @workers = count.times.map do |i|
        Worker.new(self, i+1)
      end
    end


    def run!
      RFlow.logger.debug "Running shard #{name} with #{count} workers"
      workers.each do |worker|
        worker.launch
      end

      RFlow.logger.debug "#{count} workers started for #{name}: #{workers.map { |w| "#{w.name} (#{w.pid})" }.join(", ")}"
      workers
    end


    # TODO: Implement
    def shutdown!
    end


    # TODO: Implement
    def cleanup!
    end
  end
end
