RFlow::Configuration::RubyDSL.configure do |config|
  config.setting('rflow.log_level', 'DEBUG')
  config.setting('rflow.application_directory_path', '.')
  config.setting('rflow.application_name', 'shardapp')

  # Instantiate components
  config.shard(:process, 1) do |shard|
    shard.component 'generate_ints1', 'RFlow::Components::GenerateIntegerSequence', 'start' => 0, 'finish' => 10, 'step' => 3
  end

  config.shard(:process, 2) do |shard|
    shard.component 'generate_ints2', 'RFlow::Components::GenerateIntegerSequence', 'start' => 20, 'finish' => 30
  end

  config.component 'filter', 'RFlow::Components::RubyProcFilter', 'filter_proc_string' => 'lambda {|message| true}'
  config.component 'replicate', 'RFlow::Components::Replicate'

  config.shard(:process, 2) do |shard|
    shard.component 'output1', 'RFlow::Components::FileOutput', 'output_file_path' => 'out1'
    shard.component 'output2', 'RFlow::Components::FileOutput', 'output_file_path' => 'out2'
  end

  # Hook components together
  config.connect 'generate_ints1#out' => 'filter#in'
  config.connect 'generate_ints2#out' => 'filter#in'
  config.connect 'filter#filtered' => 'replicate#in'
  config.connect 'replicate#out' => 'output1#in'
  config.connect 'replicate#out' => 'output2#in'

end
