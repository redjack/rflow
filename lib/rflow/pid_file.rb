class RFlow
  class PIDFile
    private
    attr_reader :path

    public
    def initialize(path)
      @path = path
    end

    def read
      return nil unless File.exist? path
      File.read(path).to_i
    end

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

    def running?
      return false unless exist?
      pid = read
      return false unless pid
      Process.kill(0, pid)
      pid
    rescue Errno::ESRCH, Errno::ENOENT
      nil
    end

    # unlinks a PID file at given if it contains the current PID still
    # potentially racy without locking the directory (which is
    # non-portable and may interact badly with other programs), but the
    # window for hitting the race condition is small
    def safe_unlink
      (current_process? and unlink) rescue nil
    end

    def signal(sig)
      Process.kill(sig, read)
    end

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
