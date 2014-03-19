require 'spec_helper.rb'

require 'rflow'

describe RFlow do
  before(:all) do
    load File.join(File.dirname(__FILE__), 'fixtures', 'extensions_ints.rb')
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
      @original_directory_path = Dir.getwd
      @run_directory_path = File.join(@temp_directory_path, 'run')
      @log_directory_path = File.join(@temp_directory_path, 'log')
      Dir.mkdir @run_directory_path
      Dir.mkdir @log_directory_path
    end

    after(:each) do
      Dir.chdir @original_directory_path
    end

    def run_rflow_with_dsl(&block)
      rflow_thread = Thread.new do
        ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
        RFlow::Configuration.migrate_database
        RFlow::Configuration::RubyDSL.configure do |c|
          block.call(c)
        end

        RFlow::Configuration.merge_defaults!

        RFlow.run nil, false
      end

      # TODO: figure out a way to get rid of this sleep, as there
      # should be a better way
      sleep(2)

      # Shut down the reactor and the thread
      EM.run { EM.stop }
      rflow_thread.join
    end


    it "should run a non-sharded workflow" do

      run_rflow_with_dsl do |c|
        c.setting('rflow.log_level', 'DEBUG')
        c.setting('rflow.application_directory_path', @temp_directory_path)
        c.setting('rflow.application_name', 'nonsharded')

        c.component 'generate_ints', 'RFlow::Components::GenerateIntegerSequence', 'start' => 20, 'finish' => 30
        c.component 'output', 'RFlow::Components::FileOutput', 'output_file_path' => 'out'
        c.component 'output2', 'RFlow::Components::FileOutput', 'output_file_path' => 'out2'
        c.component 'output_even', 'RFlow::Components::FileOutput', 'output_file_path' => 'out_even'
        c.component 'output_odd', 'RFlow::Components::FileOutput', 'output_file_path' => 'out_odd'
        c.component 'output_even_odd', 'RFlow::Components::FileOutput', 'output_file_path' => 'out_even_odd'
        c.component 'generate_ints2', 'RFlow::Components::GenerateIntegerSequence', 'start' => 20, 'finish' => 30
        c.component 'output_even_odd2', 'RFlow::Components::FileOutput', 'output_file_path' => 'out_even_odd2'

        c.connect 'generate_ints#out' => 'output#in'
        c.connect 'generate_ints#out' => 'output2#in'
        c.connect 'generate_ints#even_odd_out[even]' => 'output_even#in'
        c.connect 'generate_ints#even_odd_out[odd]' => 'output_odd#in'
        c.connect 'generate_ints#even_odd_out' => 'output_even_odd#in'
        c.connect 'generate_ints2#even_odd_out' => 'output_even_odd2#in'
      end

      RFlow.shards.count.should == 1

      output_files = {
        'out'           => [20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30],
        'out2'          => [20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30],
        'out_even'      => [20, 22, 24, 26, 28, 30],
        'out_odd'       => [21, 23, 25, 27, 29],
        'out_even_odd'  => [20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30],
        'out_even_odd2' => [20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30],
      }

      output_files.each do |file_name, expected_contents|
        File.exist?(File.join(@temp_directory_path, file_name)).should be_true
        File.readlines(file_name).map(&:to_i).should == expected_contents
      end
    end


    it "should run a sharded workflow" do
      run_rflow_with_dsl do |c|
        c.setting('rflow.log_level', 'DEBUG')
        c.setting('rflow.application_directory_path', @temp_directory_path)
        c.setting('rflow.application_name', 'sharded')

        # Instantiate components
        c.shard 's1', :process => 3 do |s|
          s.component 'generate_ints1', 'RFlow::Components::GenerateIntegerSequence', 'start' => 0, 'finish' => 10, 'step' => 3
        end

        c.shard 's2', :type => :process, :count => 2 do |s|
          s.component 'generate_ints2', 'RFlow::Components::GenerateIntegerSequence', 'start' => 20, 'finish' => 30
        end

        c.component 'generate_ints3', 'RFlow::Components::GenerateIntegerSequence', 'start' => 100, 'finish' => 105

        c.shard 's3', :process => 2 do |s|
          s.component 'output1', 'RFlow::Components::FileOutput', 'output_file_path' => 'out1'
          s.component 'output2', 'RFlow::Components::FileOutput', 'output_file_path' => 'out2'
        end

        c.component 'output3', 'RFlow::Components::FileOutput', 'output_file_path' => 'out3'
        c.component 'output_all', 'RFlow::Components::FileOutput', 'output_file_path' => 'out_all'

        # Hook components together
        c.connect 'generate_ints1#out' => 'output1#in'
        c.connect 'generate_ints2#out' => 'output2#in'
        c.connect 'generate_ints3#out' => 'output3#in'
        c.connect 'generate_ints1#out' => 'output_all#in'
        c.connect 'generate_ints2#out' => 'output_all#in'
        c.connect 'generate_ints3#out' => 'output_all#in'
      end

      # TODO: figure out a way to get rid of this sleep, as there
      # should be a better way
      sleep(2)

      RFlow.shards.count.should == 4
      RFlow.shards.values.map(&:count).should == [1, 3, 2, 2]

      output_files = {
        File.join(@temp_directory_path, 'out1')    => [0, 3, 6, 9] * 3,
        File.join(@temp_directory_path, 'out2')    => (20..30).to_a * 2,
        File.join(@temp_directory_path, 'out3')    => (100..105).to_a,
        File.join(@temp_directory_path, 'out_all') => [0, 3, 6, 9] * 3 + (20..30).to_a * 2 + (100..105).to_a
      }

      output_files.each do |file_name, expected_contents|
        File.exist?(file_name).should be_true
        File.readlines(file_name).map(&:to_i).sort.should == expected_contents.sort
      end
    end


  end


end
