require 'spec_helper'
require 'open3'
require 'rflow'

class RFlow
  describe Logger do
    let(:log_file_path) { File.join(@temp_directory_path, 'logfile') }
    let(:logger_config) do
      {'rflow.log_file_path' => log_file_path,
       'rflow.log_level' => 'DEBUG'}
    end

    def initialize_logger
      @logger = described_class.new(logger_config)
    end
    let(:logger) { @logger }

    before(:each) { initialize_logger }

    it "should initialize correctly" do
      expect(File.exist?(log_file_path)).to be true

      logger.error "TESTTESTTEST"
      expect(File.read(log_file_path)).to match(/TESTTESTTEST/)

      logger.close
    end

    it "should reopen correctly" do
      moved_path = log_file_path + '.old'

      expect(File.exist?(log_file_path)).to be true
      expect(File.exist?(moved_path)).to be false

      File.rename log_file_path, moved_path

      logger.reopen

      logger.error "TESTTESTTEST"
      expect(File.read(log_file_path)).to match(/TESTTESTTEST/)
      expect(File.read(moved_path)).not_to match(/TESTTESTTEST/)

      logger.close
    end

    it "should toggle log level"
  end
end
