require 'rflow/daemon_process'
require 'rflow/shard'
require 'rflow/broker'

class RFlow
  class Master < DaemonProcess
    attr_reader :shards
    attr_reader :brokers

    def initialize(config)
      super(config['rflow.application_name'], 'Master', pid_file_path: config['rflow.pid_file_path'])
      @shards = config.shards.map {|config| Shard.new(config) }
      RFlow.logger.context_width = @shards.flat_map(&:workers).map(&:name).map(&:length).max
      @brokers = config.connections.flat_map(&:brokers).map {|config| Broker.build(config) }
    end

    def spawn_subprocesses
      RFlow.logger.debug "Running #{brokers.count} brokers" if brokers.count > 0
      brokers.each(&:spawn!)
      RFlow.logger.debug "#{brokers.count} brokers started: #{brokers.map { |w| "#{w.name} (#{w.pid})" }.join(', ')}" if brokers.count > 0

      shards.each(&:run!)
    end

    def subprocesses
      brokers + shards.flat_map(&:workers)
    end

    def run_process
      EM.run do
        # TODO: Monitor the workers
      end
    end
  end
end
