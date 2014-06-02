class RFlow
  class ChildProcess
    attr_reader :pid, :name

    def initialize(name, role = name)
      @name = name
      @role = role
    end

    # Launch another process to execute the child. The parent
    # process retains the original worker object (with pid and IPC
    # pipe) to allow for process management
    def spawn!
      establish_child_pipe

      @pid = fork
      if @pid
        return_after_child_starts
      else
        run_child_process
      end
    end

    def run_child_process
      @child_pipe_w.close
      register_logging_context
      update_process_name
      handle_signals

      RFlow.logger.info "#{@role} started"
      run_process
      exit 0
    ensure
      unhandle_signals
    end

    def shutdown!(signal)
      RFlow.logger.info "Shutting down #{@name} due to #{signal}"
      unhandle_signals
    end

    private
    def establish_child_pipe
      @child_pipe_r, @child_pipe_w = IO.pipe
      [@child_pipe_r, @child_pipe_w].each {|io| io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) }
    end

    def return_after_child_starts
      @child_pipe_r.close
      self
    end

    def register_logging_context
      # arrange for child's name to appear in log messages
      Log4r::NDC.push @name
    end

    def update_process_name
      # set the visible process name to match the child's name
      $0 += " #{@name}"
    end

    def handle_signals
      ['SIGTERM', 'SIGINT', 'SIGQUIT'].each do |signal|
        trap_signal(signal) do
          shutdown! signal
          exit! 0
        end
      end

      trap_signal 'SIGUSR1' do
        RFlow.logger.reopen
      end

      trap_signal 'SIGUSR2' do
        RFlow.logger.toggle_log_level
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
  end
end
