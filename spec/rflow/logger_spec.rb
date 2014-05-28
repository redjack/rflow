require 'spec_helper'
require 'open3'
require 'rflow'

class RFlow
  describe Logger do
    let :log_file_path do
      File.join(@temp_directory_path, 'logfile')
    end

    let :logger_config do
      {
        'rflow.log_file_path' => log_file_path,
        'rflow.log_level' => 'DEBUG',
      }
    end

    it "should initialize correctly" do
      logger = described_class.new(logger_config)

      File.exist?(log_file_path).should_not be_nil

      logger.error "TESTTESTTEST"
      File.read(log_file_path).should match(/TESTTESTTEST/)

      logger.close
    end

    it "should reopen correctly" do
      moved_path = log_file_path + '.old'

      logger = described_class.new(logger_config)
      File.exist?(log_file_path).should be_true
      File.exist?(moved_path).should be_false

      File.rename log_file_path, moved_path

      logger.reopen

      logger.error "TESTTESTTEST"
      File.read(log_file_path).should match(/TESTTESTTEST/)
      File.read(moved_path).should_not match(/TESTTESTTEST/)

      logger.close
    end

    it "should toggle log level"
  end
end
