require 'spec_helper.rb'

require 'rflow'

describe RFlow do
  before(:each) do
    @fixture_directory_path = File.join(File.dirname(__FILE__), 'fixtures')
  end


  describe 'logger' do
    it "should initialize correctly" do
      log_file_path = File.join(@temp_directory_path, 'logfile')
      RFlow.initialize_logger log_file_path

      File.exist?(log_file_path).should_not be_nil

      RFlow.logger.error "TESTTESTTEST"
      File.read(log_file_path).should match(/TESTTESTTEST/)

      RFlow.close_log_file
    end

    it "should reopen correctly" do
      log_file_path = File.join(@temp_directory_path, 'logfile')
      moved_path = log_file_path + '.old'

      RFlow.initialize_logger log_file_path
      File.exist?(log_file_path).should be_true
      File.exist?(moved_path).should be_false

      File.rename log_file_path, moved_path

      RFlow.reopen_log_file

      RFlow.logger.error "TESTTESTTEST"
      File.read(log_file_path).should match(/TESTTESTTEST/)
      File.read(moved_path).should_not match(/TESTTESTTEST/)

      RFlow.close_log_file
    end

    it "should toggle log level" do
    end
  end

  describe '.run' do
    before(:each) do
      @run_directory_path = File.join(@temp_directory_path, 'run')
      @log_directory_path = File.join(@temp_directory_path, 'log')
      Dir.mkdir @run_directory_path
      Dir.mkdir @log_directory_path
    end

    it "should startup and run correctly with non-trivial workflow" do
      config_file_path = File.join(@fixture_directory_path, 'config_ints.rb')
      extensions_path = File.join(@fixture_directory_path, 'extensions_ints.rb')
      config_database_path = File.join(@temp_directory_path, 'config.sqlite')

      # Load the new database with the fixtured config file
      RFlow::Configuration::initialize_database(config_database_path, config_file_path)
      File.exist?(config_database_path).should be_true

      # Load the fixtured extensions
      load extensions_path

      current_wd = Dir.getwd

      # Startup RFlow in its own thread
      rflow_thread = Thread.new do
        RFlow.run config_database_path, false
      end

      # TODO: figure out a way to get rid of this sleep, as there
      # should be a better way
      sleep(2)

      # RFlow changes the wd ... set it back so RSpec doesn't complain
      Dir.chdir current_wd

      output_files = {
        File.join(@temp_directory_path, 'out')           => [20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30],
        File.join(@temp_directory_path, 'out2')          => [20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30],
        File.join(@temp_directory_path, 'out_even')      => [20, 22, 24, 26, 28, 30],
        File.join(@temp_directory_path, 'out_odd')       => [21, 23, 25, 27, 29],
        File.join(@temp_directory_path, 'out_even_odd')  => [20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30],
        File.join(@temp_directory_path, 'out_even_odd2') => [20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30],
      }


      output_files.each do |file_name, expected_contents|
        File.exist?(file_name).should be_true
        File.readlines(file_name).map(&:to_i).should == expected_contents
      end
    end
  end


end
