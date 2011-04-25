RFlow.configure do |config|
  config.work_directory_path = './'
  config.component_directory_path
  config.log_directory_path
  config.run_directory_path
  config.schema_directory_path

  config.flow
  config.connections
end
