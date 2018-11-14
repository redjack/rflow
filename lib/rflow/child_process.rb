require 'fcntl'

class RFlow
  # Encapsulates a child process being managed by RFlow.
  class ChildProcess
    # The PID of the child process.
    # @return [Fixnum]
    attr_reader :pid
    # The name of the child process.
    # @return [String]
    attr_reader :name

    # Symbolic constant for SIGINFO as this is only defined on BSD and not in Ruby.
    SIGINFO = 29

    # @param name [String] process name
    # @param role [String] role to be played by the process, for logging (Master, Broker, etc.)
    def initialize(name, role = name)
      @name = name
      @role = role
    end

    # Launch another process to execute the child. The parent
    # process retains the original worker object (with pid and IPC
    # pipe) to allow for process management. Parent will
    # return once the child starts; child will update its process
    # name, detach from the process group, set up signal handlers, and
    # execute {run_child_process}; when that returns, it will
    # exit with return code 0.
    # @return [void]
    def spawn!
      establish_child_pipe
      drop_database_connections

      @pid = fork
      if @pid
        return_after_child_starts
      else
        run_child_process
      end
    end

    protected
    def run_child_process
      @child_pipe_w.close
      register_logging_context
      update_process_name
      detach_process_group
      handle_signals

      RFlow.logger.info "#{@role} started"
      run_process
      exit 0
    ensure
      unhandle_signals
    end

    def run_process; end

    public
    # Called when the child process needs to be shut down, before it dies.
    # Clears signal handlers.
    # @param signal [String] SIG*, whichever signal caused the shutdown
    # @return [void]
    def shutdown!(signal)
      RFlow.logger.info "Shutting down due to #{signal}"
      unhandle_signals
    end

    private
    def establish_child_pipe
      @child_pipe_r, @child_pipe_w = IO.pipe
      [@child_pipe_r, @child_pipe_w].each {|io| io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) }
    end

    # Holding database connections over the fork causes problems. Instead,
    # let them be automatically restored after the fork.
    def drop_database_connections
      ::ActiveRecord::Base.clear_all_connections!
    end

    def return_after_child_starts
      @child_pipe_r.close
      self
    end

    def register_logging_context
      # arrange for child's name to appear in log messages
      RFlow.logger.add_logging_context sprintf("%-#{RFlow.logger.context_width}s", @name)
    end

    def update_process_name
      # set the visible process name to match the child's name
      $0 += " #{@name}"
    end

    # detach from parent process group so shutdown remains orderly (prevent
    # signals from being delivered to entire group)
    def detach_process_group
      Process.setpgid(0, 0)
    end

    def handle_signals
      Signal.trap 'SIGCHLD', 'DEFAULT' # make sure child process can run subshells

      ['SIGTERM', 'SIGINT', 'SIGQUIT', 'SIGHUP'].each do |signal|
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

      trap_signal SIGINFO do
        RFlow.logger.dump_threads
      end
    end

    def unhandle_signals
      ['SIGTERM', 'SIGINT', 'SIGQUIT', 'SIGHUP', 'SIGCHLD', 'SIGUSR1', 'SIGUSR2', SIGINFO].each do |signal|
        Signal.trap signal, 'DEFAULT'
      end
    end

    def trap_signal(signal)
      # Log4r and traps don't mix, so we need to put it in another thread
      context = RFlow.logger.clone_logging_context
      Signal.trap signal do
        Thread.new do
          RFlow.logger.apply_logging_context context
          yield
        end.join
      end
    end
  end
end
