RFlow::Configuration::RubyDSL.configure do |config|
  # Configure the settings, which include paths for various files, log
  # levels, and component specific stuffs
  config.setting('rflow.log_level', 'DEBUG')
  config.setting('rflow.application_directory_path', '../tmp')
  config.setting('rflow.application_name', 'testapp')

  # Instantiate components
  config.component 'generate_ints', 'RFlow::Components::GenerateIntegerSequence', 'start' => 20, 'finish' => 30
  config.component 'generate_ints2', 'RFlow::Components::GenerateIntegerSequence', 'start' => 20, 'finish' => 30
  config.component 'output', 'RFlow::Components::FileOutput', 'output_file_path' => '../tmp/out'
  config.component 'output2', 'RFlow::Components::FileOutput', 'output_file_path' => '../tmp/out2'
  config.component 'output_even', 'RFlow::Components::FileOutput', 'output_file_path' => '../tmp/out_even'
  config.component 'output_odd', 'RFlow::Components::FileOutput', 'output_file_path' => '../tmp/out_odd'
  config.component 'output_even_odd', 'RFlow::Components::FileOutput', 'output_file_path' => '../tmp/out_even_odd'
  config.component 'output_even_odd2', 'RFlow::Components::FileOutput', 'output_file_path' => '../tmp/out_even_odd2'

  # Hook components together
  config.connect 'generate_ints#out' => 'output#in'
  config.connect 'generate_ints#out' => 'output2#in'
  config.connect 'generate_ints#even_odd_out[even]' => 'output_even#in'
  config.connect 'generate_ints#even_odd_out[odd]' => 'output_odd#in'
  config.connect 'generate_ints#even_odd_out' => 'output_even_odd#in'
  config.connect 'generate_ints2#even_odd_out' => 'output_even_odd2#in'
end
