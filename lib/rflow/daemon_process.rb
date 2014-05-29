class RFlow
  class DaemonProcess
    def initialize(name, role = name)
      @name = name
      @role = role
    end

    def daemonize!
      RFlow.logger.info "#{@name} daemonizing"
      establish_daemon_pipe

      parent = fork
      if parent
        exit_after_daemon_starts
      else
        daemonize_process
      end
    end

    def run!
      register_logging_context
      update_process_name
      spawn_subprocesses
      handle_signals
      signal_successful_start

      RFlow.logger.info "#{@role} started"
      run_process
    ensure
      unhandle_signals
    end

    def spawn_subprocesses; end
    def subprocesses; []; end

    def shutdown!(reason)
      RFlow.logger.info "#{@name} shutting down due to #{reason}"
      signal_subprocesses('QUIT')
      RFlow.logger.info "#{@name} exiting"
      exit 0
    end

    private
    def establish_daemon_pipe
      @daemon_pipe_r, @daemon_pipe_w = IO.pipe
      [@daemon_pipe_r, @daemon_pipe_w].each {|io| io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) }
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
        begin; stream.reopen "/dev/null"; rescue ::Exception; end
      end
    end

    def register_logging_context
      # arrange for process's name to appear in log messages
      Log4r::NDC.clear
      Log4r::NDC.push @name
    end

    def update_process_name
      # set the visible process name to match the process's name
      $0 = @name
    end

    def handle_signals
      ['SIGTERM', 'SIGINT', 'SIGQUIT', 'SIGCHLD'].each do |signal|
        trap_signal(signal) { shutdown! signal }
      end

      trap_signal 'SIGUSR1' do
        RFlow.logger.reopen
        signal_subprocesses signal
      end

      trap_signal 'SIGUSR2' do
        RFlow.logger.toggle_log_level
        signal_subprocesses signal
      end
    end

    def unhandle_signals
      ['SIGTERM', 'SIGINT', 'SIGQUIT', 'SIGCHLD', 'SIGUSR1', 'SIGUSR2'].each do |signal|
        Signal.trap signal, 'DEFAULT'
      end
    end

    def trap_signal(signal)
      # Log4r and traps don't mix, so we need to put it in another thread
      Signal.trap signal do
        Thread.new { yield }.join
      end
    end

    def signal_successful_start
      if @daemon_pipe_w
        @daemon_pipe_w.syswrite($$.to_s)
        @daemon_pipe_w.close rescue nil
      end
    end

    def signal_subprocesses(signal)
      subprocesses.each do |p|
        RFlow.logger.info "Signaling #{p.name} with #{signal}"
        Process.kill(signal, p.pid)
      end
    end
  end
end
