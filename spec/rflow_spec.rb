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

  describe 'run' do
    it "should startup and run correctly with non-trivial workflow" do
      Dir.mkdir File.join(@temp_directory_path, 'run')
      Dir.mkdir File.join(@temp_directory_path, 'log')

      config_file_path = File.join(@fixture_directory_path, 'config.rb')
      extensions_path = File.join(@fixture_directory_path, 'extensions.rb')
      config_database_path = File.join(@temp_directory_path, 'config.sqlite')

      `rflow -d #{config_database_path} -c #{config_file_path} load`

      File.exist?(config_database_path).should be_true
      
      load extensions_path

      rflow_thread = Thread.new do
        RFlow.run config_database_path, false
      end

      # TODO: figure out a way to get rid of this sleep, as it is not correct
      sleep(5)

      all_file_path = File.join(@temp_directory_path, 'out')
      even_file_path = File.join(@temp_directory_path, 'out_even')
      odd_file_path = File.join(@temp_directory_path, 'out_odd')
      even_odd_file_path = File.join(@temp_directory_path, 'out_even_odd')
      
      File.exist?(all_file_path).should be_true
      File.exist?(even_file_path).should be_true
      File.exist?(odd_file_path).should be_true

      File.readlines(all_file_path).map(&:to_i).should == [20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30]
      File.readlines(even_file_path).map(&:to_i).should == [20, 22, 24, 26, 28, 30]
      File.readlines(odd_file_path).map(&:to_i).should == [21, 23, 25, 27, 29]
      File.readlines(even_odd_file_path).map(&:to_i).should == [20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30]
    end
  end
  

end
