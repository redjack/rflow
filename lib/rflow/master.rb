require 'rflow/daemon_process'
require 'rflow/shard'
require 'rflow/broker'

class RFlow
  # The master/watchdog process for RFlow. Mostly exists to receive +SIGCHLD+ from subprocesses
  # so it can kill them all with +SIGQUIT+ and get restarted.
  class Master < DaemonProcess
    # The {Shard}s being managed by the {Master}.
    # @return [Array<Shard>]
    attr_reader :shards

    # The {Broker}s being managed by the {Master}.
    # @return [Array<Broker>]
    attr_reader :brokers

    def initialize(config)
      super(config['rflow.application_name'], 'Master', pid_file_path: config['rflow.pid_file_path'])
      @shards = config.shards.map {|config| Shard.new(config) }
      RFlow.logger.context_width = @shards.flat_map(&:workers).map(&:name).map(&:length).max
      @brokers = config.connections.flat_map(&:brokers).map {|config| Broker.build(config) }
    end

    # Override of {spawn_subprocesses} that actually spawns them,
    # then calls {Shard#run!} on each.
    # @return [void]
    def spawn_subprocesses
      RFlow.logger.debug "Running #{brokers.count} brokers" if brokers.count > 0
      brokers.each(&:spawn!)
      RFlow.logger.debug "#{brokers.count} brokers started: #{brokers.map { |w| "#{w.name} (#{w.pid})" }.join(', ')}" if brokers.count > 0

      shards.each(&:run!)
    end

    # Override of {subprocesses} that includes the {Broker}s and
    # every {Shard::Worker} of every {Shard}.
    # @return [Array<ChildProcess>]
    def subprocesses
      brokers + shards.flat_map(&:workers)
    end

    # Override that starts EventMachine and waits until it gets stopped.
    # @return [void]
    def run_process
      EM.run do
        # TODO: Monitor the workers
      end
    end
  end
end
