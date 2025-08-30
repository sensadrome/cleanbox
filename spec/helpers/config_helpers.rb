# frozen_string_literal: true

def write_config_to_file(config_path, config = {})
  File.write(config_path, config.to_yaml)
  Configuration.configure(config)
end

def read_config_from_file(config_path)
  YAML.load_file(config_path).transform_keys(&:to_sym)
rescue StandardError
  {}
end

# Shared context for default configuration options
RSpec.shared_context 'default config options' do
  let(:temp_config_dir) { Dir.mktmpdir('cleanbox_config_dir') }
  let(:temp_config_path) { File.join(temp_config_dir, 'test_config.yml') }

  let(:config_options) do
    {
      data_dir: nil,
      config_file: temp_config_path
    }
  end

  # Set the new path for "File.expand_path('~/.cleanbox.yml'"
  let(:test_home_config_dir) { Dir.mktmpdir('cleanbox_test_home') }
  let(:test_home_config_path) { File.join(test_home_config_dir, '.cleanbox.yml') }
end

# Include the shared context globally
RSpec.configure do |config|
  config.include_context 'default config options'

  # Configure Configuration for each test
  config.before(:each) do
    # Mock home_config to use our test file
    allow(Configuration).to receive(:home_config).and_return(test_home_config_path)

    # Configure Configuration with the test options
    # warn "Configuring Configuration with #{config_options}"
    Configuration.configure(config_options)
  end

  # Clean up temporary directories
  config.after(:each) do
    FileUtils.rm_f(temp_config_dir)
    FileUtils.rm_f(test_home_config_dir)
  end
end
