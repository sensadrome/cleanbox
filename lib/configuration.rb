# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require_relative 'core_ext'

class Configuration
  class << self
    attr_accessor :options, :data_dir
    attr_reader :config_file_path

    def configure(command_line_options = {})
      @original_command_line_options ||= command_line_options
      @options = default_options
      @data_dir = resolve_data_dir_from_options(command_line_options)
      @config_file_path = resolve_config_file_path(command_line_options)
      load_config_file
      @options = @options.deep_merge(command_line_options)
    end

    def config_loaded?
      @config_loaded || false
    end

    private

    def default_options
      {
        auth_type: nil,
        blacklist_folder: nil,
        data_dir: nil,
        file_from_folders: [],
        file_unread: false,
        hold_days: 7,
        host: '',
        level: 'info',
        list_domain_map: {},
        list_domains: [],
        list_folders: [],
        list_since_months: 12,
        log_file: nil,
        sent_folder: 'Sent Items',
        sent_since_months: 24,
        unjunk: false,
        unjunk_folders: [],
        username: nil,
        valid_since_months: 12,
        verbose: false,
        whitelist_folders: [],
        whitelisted_domains: []
      }
    end

    def resolve_data_dir_from_options(options)
      if options[:data_dir]
        File.expand_path(options[:data_dir])
      elsif ENV['CLEANBOX_DATA_DIR']
        File.expand_path(ENV['CLEANBOX_DATA_DIR'])
      end
    end

    def resolve_config_file_path(options)
      if options[:config_file]
        File.expand_path(options[:config_file])
      else
        resolve_default_config_path
      end
    end

    def resolve_default_config_path
      # Priority 1: CLEANBOX_CONFIG environment variable
      if ENV['CLEANBOX_CONFIG']
        config_path = ENV['CLEANBOX_CONFIG']
        # If relative path AND data_dir is set, prepend data directory
        config_path = File.join(@data_dir, config_path) if !config_path.start_with?('/') && @data_dir
        # Always expand to absolute path
        return File.expand_path(config_path)
      end

      # Priority 2: Check for config file in data directory (from --data-dir or CLEANBOX_DATA_DIR)
      if @data_dir
        data_dir_config = File.join(@data_dir, 'cleanbox.yml')
        return data_dir_config if File.exist?(data_dir_config)
      end

      # Priority 3: Check for config file in CLEANBOX_DATA_DIR environment variable
      if ENV['CLEANBOX_DATA_DIR']
        env_data_dir = File.expand_path(ENV['CLEANBOX_DATA_DIR'])
        env_data_dir_config = File.join(env_data_dir, 'cleanbox.yml')
        return env_data_dir_config if File.exist?(env_data_dir_config)
      end

      # Priority 4: Fallback to user's home directory
      home_config
    end

    # :nocov:
    def home_config
      File.expand_path('~/.cleanbox.yml')
    end
    # :nocov:

    def load_config_file
      return unless @config_file_path && File.exist?(@config_file_path)

      config = YAML.load_file(@config_file_path) || {}
      config = config.transform_keys(&:to_sym)

      @options = @options.deep_merge(config)
      @config_loaded = true
    end
  end
end
