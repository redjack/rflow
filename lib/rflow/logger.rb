require 'log4r'

class RFlow
  # The customized logger for RFlow applications that flows to the configured log file.
  class Logger
    extend Forwardable
    include Log4r

    # @!visibility private
    LOG_PATTERN_FORMAT = '%-5l [%d] %x (%-5p) - %M'
    # @!visibility private
    DATE_METHOD = 'xmlschema(6)'
    # @!visibility private
    LOG_PATTERN_FORMATTER = PatternFormatter.new :pattern => LOG_PATTERN_FORMAT, :date_method => DATE_METHOD

    private
    attr_accessor :internal_logger
    attr_accessor :log_file_path, :log_level, :log_name

    public
    # For the current logging context, how wide the field is where we're going to write the context/process name.
    # @return [Integer]
    attr_accessor :context_width

    # make sure Log4r is initialized; ignored if custom levels are already set
    Log4r.define_levels(*Log4rConfig::LogLevels)

    # Delegate log methods to internal logger
    def_delegators :@internal_logger,
      *Log4r::LNAMES.map(&:downcase).map(&:to_sym),
      *Log4r::LNAMES.map(&:downcase).map {|n| "#{n}?".to_sym }

    def initialize(config, include_stdout = false)
      reconfigure(config, include_stdout)
    end

    # Reconfigure the log file.
    # @return [void]
    def reconfigure(config, include_stdout = false)
      @log_file_path = config['rflow.log_file_path']
      @log_level = config['rflow.log_level'] || 'WARN'
      @log_name = if config['rflow.application_name']; config['rflow.application_name']
                  elsif log_file_path; File.basename(log_file_path)
                  else ''; end

      establish_internal_logger
      hook_up_logfile
      hook_up_stdout if include_stdout
      register_logging_context

      internal_logger
    end

    # Reopen the logs at their configured filesystem locations. Presumably the previous
    # log files have been renamed by now.
    # @return [void]
    def reopen
      # TODO: Make this less of a hack, although Log4r doesn't support
      # it, so it might be permanent
      log_file = Outputter['rflow.log_file'].instance_variable_get(:@out)
      File.open(log_file.path, 'a') { |tmp_log_file| log_file.reopen(tmp_log_file) }
    end

    # Close the logger.
    # @return [void]
    def close
      Outputter['rflow.log_file'].close
    end

    # Update the log level.
    # @return [void]
    def level=(level)
      internal_logger.level = LNAMES.index(level.to_s) || level
    end

    # Toggle the log level between +DEBUG+ and whatever the default is. The previous
    # level is saved to be toggled back the next time this method is called.
    # @return [void]
    def toggle_log_level
      original_log_level = LNAMES[internal_logger.level]
      new_log_level = (original_log_level == 'DEBUG' ? log_level : 'DEBUG')

      internal_logger.warn "Changing log level from #{original_log_level} to #{new_log_level}"
      internal_logger.level = LNAMES.index new_log_level
    end

    # Send a complete thread dump of the current process out to the logger.
    # @return [void]
    def dump_threads
      Thread.list.each do |t|
        info "Thread #{t.inspect}:"
        t.backtrace.each {|b| info "  #{b}" }
        info '---'
      end
      info 'Thread dump complete.'
    end

    # Clone the logging context so changes to it will not affect the
    # exiting logging context.
    # @return [void]
    def clone_logging_context
      Log4r::NDC.clone_stack
    end

    # Replace the current logging context.
    # @return [void]
    def apply_logging_context(context)
      Log4r::NDC.inherit(context)
    end

    # Clear the current logging context.
    # @return [void]
    def clear_logging_context
      Log4r::NDC.clear
    end

    # Add more logging context to the stack.
    # @return [void]
    def add_logging_context(context)
      Log4r::NDC.push context
    end

    private
    def establish_internal_logger
      @internal_logger = Log4r::Logger.new(log_name).tap do |logger|
        logger.level = LNAMES.index log_level
        logger.trace = true
      end
    end

    def hook_up_logfile
      if log_file_path
        begin
          internal_logger.add FileOutputter.new('rflow.log_file', :filename => log_file_path, :formatter => LOG_PATTERN_FORMATTER)
        rescue Exception => e
          raise ArgumentError, "Log file '#{File.expand_path log_file_path}' problem: #{e.message}\n#{e.backtrace.join("\n")}"
        end
      end
    end

    def hook_up_stdout
      internal_logger.add StdoutOutputter.new('rflow_stdout', :formatter => LOG_PATTERN_FORMATTER)
    end

    def register_logging_context
      Log4r::NDC.clear
      Log4r::NDC.push(log_name)
    end
  end
end
