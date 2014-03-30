require 'rflow/pid_file'
require 'rflow/shard'

class RFlow
  class Master

    attr_accessor :name, :app_name, :pid_file, :grandparent_pipe
    attr_accessor :shards

    def initialize(config)
      @app_name = config['rflow.application_name']
      @name = app_name + ' master'
      @pid_file = PIDFile.new(config['rflow.pid_file_path'])
      @shards = config.shards.map do |shard_config|
        Shard.new(shard_config)
      end
    end

    def run
      $0 = app_name
      RFlow.logger.info "Master started"

      shards.each {|s| s.run!}

      # Signal the grandparent that we are running
      if grandparent_pipe
        grandparent_pipe.syswrite($$.to_s)
        grandparent_pipe.close rescue nil
      end

      pid_file.write

      Log4r::NDC.clear
      Log4r::NDC.push name
      $0 = name

      EM.run do
        # Do something here to monitor the shards
      end

      @pid_file.safe_unlink
    end

    def daemonize!
      RFlow.logger.info "#{app_name} daemonizing"

      rd, wr = IO.pipe
      grandparent = $$

      # Grandparent
      if fork
        wr.close # grandparent does not write
        master_pid = (rd.readpartial(16) rescue nil).to_i
        unless master_pid > 1
          RFlow.logger.warn "Master failed to start"
          exit!(1)
        end
        exit 0
      end

      Process.daemon(true, true)

      rd.close # master does not read

      @grandparent_pipe = wr

      # Close standard IO
      $stdout.sync = $stderr.sync = true
      $stdin.binmode; $stdout.binmode; $stderr.binmode
      begin; $stdin.reopen  "/dev/null"; rescue ::Exception; end
      begin; $stdout.reopen "/dev/null"; rescue ::Exception; end
      begin; $stderr.reopen "/dev/null"; rescue ::Exception; end

      $$
    end

    def shutdown
      RFlow.logger.info "#{app_name} shutting down"

      RFlow.logger.debug "Shutting down shards"
      shards.values.each do |shard|
        RFlow.logger.debug "Shutting down shard #{shard.name}"
        shard.shutdown!
      end

      RFlow.logger.debug "Cleaning up shards"
      shards.values.each do |shard|
        RFlow.logger.debug "Cleaning up shard #{shard.name}"
        shard.cleanup!
      end

      pid_file.safe_unlink
      RFlow.logger.info "#{app_name} exiting"
      exit 0
    end

    def reload
      # TODO: Actually do a real reload
      RFlow.logger.info "#{app_name} reloaded"
    end

  end
end
