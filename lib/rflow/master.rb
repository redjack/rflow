require 'rflow/daemon_process'
require 'rflow/pid_file'
require 'rflow/shard'
require 'rflow/broker'

class RFlow
  class Master < DaemonProcess
    attr_reader :shards
    attr_reader :brokers

    def initialize(config)
      super(config['rflow.application_name'], 'Master')
      @pid_file = PIDFile.new(config['rflow.pid_file_path'])
      @shards = config.shards.map {|config| Shard.new(config) }
      RFlow.logger.context_width = @shards.flat_map(&:workers).map(&:name).map(&:length).max
      @brokers = config.connections.flat_map(&:brokers).map {|config| Broker.build(config) }
    end

    def run!
      write_pid_file
      super
    ensure
      remove_pid_file
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

    def shutdown!(reason)
      remove_pid_file
      super
    end

    private
    def write_pid_file; @pid_file.write; end
    def remove_pid_file; @pid_file.safe_unlink; end
  end
end
