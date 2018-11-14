class RFlow
  # Represents a file on disk that contains RFlow's PID, for process management.
  class PIDFile
    private
    attr_reader :path

    public
    def initialize(path)
      @path = path
    end

    # Read the pid file and get the PID from it.
    # @return [Integer]
    def read
      return nil unless File.exist? path
      contents = File.read(path)
      if contents.empty?
        RFlow.logger.warn "Ignoring empty PID file #{path}"
        nil
      else
        contents.to_i
      end
    end

    # Write a new PID out to the pid file.
    # @return [Integer] the pid
    def write(pid = $$)
      return unless validate?

      RFlow.logger.debug "Writing PID #{pid} to file '#{to_s}'"
      tmp_path = File.join(File.dirname(path), ".#{File.basename(path)}")
      if File.exist? tmp_path
        RFlow.logger.warn "Deleting stale temp PID file #{tmp_path}"
        File.delete(tmp_path)
      end
      pid_fp = begin
                 File.open(tmp_path, File::RDWR|File::CREAT|File::EXCL, 0644)
               rescue Errno::ENOENT => e
                 RFlow.logger.fatal "Error while writing temp PID file '#{tmp_path}'; containing directory may not exist?"
                 RFlow.logger.fatal "Exception #{e.class}: #{e.message}"
                 abort
               rescue Errno::EACCES => e
                 RFlow.logger.fatal "Access error while writing temp PID file '#{tmp_path}'"
                 RFlow.logger.fatal "Exception #{e.class}: #{e.message}"
                 abort
               end
      pid_fp.syswrite("#{pid}\n")
      File.rename(pid_fp.path, path)
      pid_fp.close

      pid
    end

    # Determine if the application is running by checking the running PID and the pidfile.
    # @return [boolean]
    def running?
      return false unless exist?
      pid = read
      return false unless pid
      Process.kill(0, pid)
      pid
    rescue Errno::ESRCH, Errno::ENOENT
      nil
    end

    # Unlinks a PID file if it contains the current PID. Still
    # potentially racy without locking the directory (which is
    # non-portable and may interact badly with other programs), but the
    # window for hitting the race condition is small.
    # @return [void]
    def safe_unlink
      (current_process? and unlink) rescue nil
    end

    # Signal the process with the matching PID with a given signal.
    # @return [void]
    def signal(sig)
      Process.kill(sig, read)
    end

    # @!visibility private
    def to_s
      File.expand_path(path)
    end

    private
    def validate?
      if current_process?
        return nil
      elsif running?
        raise ArgumentError, "Process #{read.to_s} referenced in stale PID file '#{to_s}' still exists; probably attempting to run duplicate RFlow instances"
      elsif exist?
        RFlow.logger.warn "Found stale PID #{read.to_s} in PID file '#{to_s}', removing"
        unlink
      end
      true
    end

    def exist?
      File.exist? path
    end

    def current_process?
      read == $$
    end

    def unlink
      File.unlink(path)
    end
  end
end
