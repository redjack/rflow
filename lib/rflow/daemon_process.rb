require 'rflow/pid_file'

class RFlow
  class DaemonProcess
    SIGINFO = 29

    def initialize(name, role = name, options = {})
      @name = name
      @role = role
      @pid_file = PIDFile.new(options[:pid_file_path]) if options[:pid_file_path]
    end

    def daemonize!
      RFlow.logger.info "#{@name} daemonizing"
      establish_daemon_pipe
      drop_database_connections

      parent = fork
      if parent
        exit_after_daemon_starts
      else
        daemonize_process
      end
    end

    def run!
      write_pid_file
      register_logging_context
      update_process_name
      handle_signals
      spawn_subprocesses
      signal_successful_start

      RFlow.logger.info "#{@role} started"
      run_process
    ensure
      unhandle_signals
      remove_pid_file
    end

    def spawn_subprocesses; end
    def subprocesses; []; end

    def shutdown!(reason)
      RFlow.logger.info "#{@name} shutting down due to #{reason}"
      remove_pid_file
      unhandle_signals
      signal_subprocesses('QUIT')
      RFlow.logger.info "#{@name} exiting"
    end

    private
    def establish_daemon_pipe
      @daemon_pipe_r, @daemon_pipe_w = IO.pipe
      [@daemon_pipe_r, @daemon_pipe_w].each {|io| io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) }
    end

    # Holding database connections over the fork causes problems. Instead,
    # let them be automatically restored after the fork.
    def drop_database_connections
      ::ActiveRecord::Base.clear_all_connections!
    end

    def exit_after_daemon_starts
      @daemon_pipe_w.close

      # Parent waits for a PID on the pipe indicating that the
      # child successfully started.
      child_pid = (@daemon_pipe_r.readpartial(16) rescue nil).to_i
      @daemon_pipe_r.close
      if child_pid > 1
        RFlow.logger.info "#{@role} indicated successful daemonization"
        exit 0
      else
        RFlow.logger.error "#{@role} failed to start"
        STDERR.puts "\n\n*** #{@role} failed to start; see log file for details"
        exit! 1
      end
    end

    def daemonize_process
      @daemon_pipe_r.close
      Process.daemon(true, true)
      close_stdio_streams
    end

    def close_stdio_streams
      $stdout.sync = $stderr.sync = true
      [$stdin, $stdout, $stderr].each do |stream|
        stream.binmode
        begin; stream.reopen '/dev/null'; rescue ::Exception; end
      end
    end

    def register_logging_context
      # arrange for process's name to appear in log messages
      RFlow.logger.clear_logging_context
      RFlow.logger.add_logging_context @name
    end

    def update_process_name
      # set the visible process name to match the process's name
      $0 = @name
    end

    def handle_signals
      ['SIGTERM', 'SIGINT', 'SIGQUIT', 'SIGCHLD'].each do |signal|
        trap_signal(signal) do |return_code|
          exit_status = if signal == 'SIGCHLD'
                          pid, status = Process.wait2
                          status.exitstatus || 0
                        else
                          0
                        end
          shutdown! signal
          exit! exit_status
        end
      end

      trap_signal 'SIGUSR1' do
        RFlow.logger.reopen
        signal_subprocesses 'SIGUSR1'
      end

      trap_signal 'SIGUSR2' do
        RFlow.logger.toggle_log_level
        signal_subprocesses 'SIGUSR2'
      end

      trap_signal SIGINFO do
        RFlow.logger.dump_threads
        # don't tell child processes to dump, too spammy
      end
    end

    def unhandle_signals
      ['SIGTERM', 'SIGINT', 'SIGQUIT', 'SIGCHLD', 'SIGUSR1', 'SIGUSR2', SIGINFO].each do |signal|
        Signal.trap signal, 'DEFAULT'
      end
    end

    def trap_signal(signal)
      # Log4r and traps don't mix, so we need to put it in another thread
      return_code = $?
      context = RFlow.logger.clone_logging_context
      Signal.trap signal do
        Thread.new do
          RFlow.logger.apply_logging_context context
          yield return_code
        end.join
      end
    end

    def signal_successful_start
      if @daemon_pipe_w
        @daemon_pipe_w.syswrite($$.to_s)
        @daemon_pipe_w.close rescue nil
      end
    end

    def signal_subprocesses(signal)
      subprocesses.reject {|p| p.pid.nil? }.each do |p|
        RFlow.logger.info "Signaling #{p.name} with #{signal}"
        begin
          Process.kill(signal, p.pid)
        rescue Errno::ESRCH
          # process already died and was waited for, ignore
        end
      end
    end

    def write_pid_file; @pid_file.write if @pid_file; end
    def remove_pid_file; @pid_file.safe_unlink if @pid_file; end
  end
end
