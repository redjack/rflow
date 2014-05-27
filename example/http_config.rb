RFlow::Configuration::RubyDSL.configure do |config|
  # Configure the settings, which include paths for various files, log
  # levels, and component specific stuffs
  config.setting('rflow.log_level', 'INFO')
  config.setting('rflow.application_directory_path', '.')

  # Instantiate components
  config.component 'http_server', 'HTTPServer', 'port' => 8080
  config.component 'filter', 'RFlow::Components::RubyProcFilter', 'filter_proc_string' => 'message.data.path == "/awesome"'
  config.component 'replicate', 'RFlow::Components::Replicate'
  config.component 'file_output', 'RFlow::Components::FileOutput', 'output_file_path' => '/tmp/http_crap'
  config.component 'http_responder', 'HTTPResponder', 'response_code' => 200, 'content' => 'Hi, this teh awesome'

  #config.connect 'http_server#request_port' => 'filter#in'
  #config.connect 'filter#filtered' => 'replicate#in'
  config.connect 'http_server#request_port' => 'replicate#in'
  config.connect 'replicate#out[1]' => 'file_output#in'
  config.connect 'replicate#out[2]' => 'http_responder#request'
  config.connect 'http_responder#response' => 'http_server#response_port'
end
