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

      RFlow.logger.debug "Writing PID #{pid} file '#{to_s}'"
      pid_fp = begin
                 tmp_path = File.join(File.dirname(path), ".#{File.basename(path)}")
                 File.open(tmp_path, File::RDWR|File::CREAT|File::EXCL, 0644)
               rescue Errno::EEXIST
                 retry
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
        RFlow.logger.warn "Already running #{read.to_s}, not writing PID to file '#{to_s}'"
        return nil
      elsif running?
        raise ArgumentError, "Already running #{read.to_s}, possibly stale PID file '#{to_s}'"
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
