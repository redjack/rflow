require 'rflow/pid_file'
require 'rflow/shard'

class RFlow
  class Master
    attr_accessor :name, :pid_file, :ready_write
    attr_accessor :shards

    def initialize(config)
      @name = config['rflow.application_name']
      @pid_file = PIDFile.new(config['rflow.pid_file_path'])
      @shards = config.shards.map do |shard_config|
        Shard.new(shard_config)
      end
    end

    def handle_signals
      # Gracefully shutdown on termination signals
      ['SIGTERM', 'SIGINT', 'SIGQUIT', 'SIGCHLD'].each do |signal|
        Signal.trap signal do
          # Log4r and traps don't mix, so we need to put it in another thread
          Thread.new { shutdown(signal) }.join
        end
      end

      # Reopen logs on USR1
      ['SIGUSR1'].each do |signal|
        Signal.trap signal do
          Thread.new do
            RFlow.logger.reopen
            signal_workers(signal)
          end.join
        end
      end

      # Toggle log level on USR2
      ['SIGUSR2'].each do |signal|
        Signal.trap signal do
          Thread.new do
            RFlow.logger.toggle_log_level
            signal_workers(signal)
          end.join
        end
      end
    end

    def run
      Log4r::NDC.clear
      Log4r::NDC.push name
      $0 = name

      shards.each {|s| s.run!}

      handle_signals

      # Signal the grandparent that we are running
      if ready_write
        ready_write.syswrite($$.to_s)
        ready_write.close rescue nil
      end

      pid_file.write

      RFlow.logger.info "Master started"

      EM.run do
        # TODO: Monitor the workers
      end

      @pid_file.safe_unlink
    end

    def daemonize!
      RFlow.logger.info "#{name} daemonizing"

      ready_read, @ready_write = IO.pipe
      [ready_read, @ready_write].each { |io| io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) }

      grandparent = $$

      if fork
        # Grandparent waits for a PID on the pipe indicating that the
        # master successfully started.
        @ready_write.close # grandparent does not write
        master_pid = (ready_read.readpartial(16) rescue nil).to_i
        unless master_pid > 1
          RFlow.logger.error "Master failed to start"
          exit! 1
        end
        RFlow.logger.info "Master indicated successful daemonization"
        exit 0
      end

      Process.daemon(true, true)

      ready_read.close # master does not read

      # Close standard IO
      $stdout.sync = $stderr.sync = true
      $stdin.binmode; $stdout.binmode; $stderr.binmode
      begin; $stdin.reopen  "/dev/null"; rescue ::Exception; end
      begin; $stdout.reopen "/dev/null"; rescue ::Exception; end
      begin; $stderr.reopen "/dev/null"; rescue ::Exception; end

      $$
    end

    def signal_workers(signal)
      shards.each do |shard|
        shard.workers.each do |worker|
          RFlow.logger.info "Signalling #{worker.name} with #{signal}"
          Process.kill(signal, worker.pid)
        end
      end
    end

    def shutdown(reason)
      RFlow.logger.info "#{name} shutting down due to #{reason}"
      signal_workers('QUIT')
      pid_file.safe_unlink
      RFlow.logger.info "#{name} exiting"
      exit 0
    end
  end
end
