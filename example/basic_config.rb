# Meat of the config file.  Stuff above this should probably be in
# separate gems and/or files that are brought in at runtime.
RFlow::Configuration::RubyDSL.configure do |config|
  # Configure the settings, which include paths for various files, log
  # levels, and component specific stuffs
  config.setting('rflow.log_level', 'DEBUG')
  config.setting('rflow.application_directory_path', '.')

  # Add schemas to the list of available.  Not convinced this is necessary
#  config.schema('schemaname', 'schematype', 'schemadata')

  # Instantiate components
  config.component 'generate_ints1', 'RFlow::Components::GenerateIntegerSequence', 'start' => 0, 'finish' => 10, 'step' => 3, 'interval_seconds' => 1
  config.component 'generate_ints2', 'RFlow::Components::GenerateIntegerSequence', 'start' => 20, 'finish' => 25
  config.component 'filter', 'RFlow::Components::RubyProcFilter', 'filter_proc_string' => 'lambda {|message| true}'
  config.component 'replicate', 'RFlow::Components::Replicate'
  config.component 'output1', 'RFlow::Components::FileOutput', 'output_file_path' => '/tmp/crap1'
  config.component 'output2', 'RFlow::Components::FileOutput', 'output_file_path' => '/tmp/crap2'
  
  # Hook components together
  # config.connect 'generate_ints#out' => 'filter#in'
  # config.connect 'filter#filtered' => 'replicate#in'
  # config.connect 'replicate#out[0]' => 'simple#in'
  # config.connect 'replicate#out[one]' => 'complex#in'
  # config.connect 'simple#out' => 'output#in'
  # config.connect 'complex#out' => 'output#in'

  config.connect 'generate_ints1#out' => 'filter#in'
  config.connect 'generate_ints2#out' => 'filter#in'
  config.connect 'filter#filtered' => 'replicate#in'
  config.connect 'replicate#out[1]' => 'output1#in'
  config.connect 'replicate#out[2]' => 'output2#in'
  # Some tests that should fail
  # output should not have an 'out' ports
#  config.connect 'output#out' => 'simple#in'
end


