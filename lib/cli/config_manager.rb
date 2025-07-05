# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module CLI
  class ConfigManager
    def initialize(config_path = nil)
      @config_path = config_path || ENV.fetch('CLEANBOX_CONFIG', File.expand_path('~/.cleanbox.yml'))
    end

    def show
      config = load_config
      if config.empty?
        puts "No configuration file found at #{@config_path}"
      else
        puts "Configuration from #{@config_path}:"
        puts config.to_yaml
      end
    end

    def get(key)
      key = key.to_sym
      config = load_config
      value = config[key]
      if value.nil?
        puts "Key '#{key}' not found in configuration"
      else
        puts value.to_yaml
      end
    end

    def set(key, value)
      key = key.to_sym
      config = load_config
      
        # Try to parse value as YAML for complex types
        begin
          parsed_value = YAML.load(value)
          config[key] = parsed_value
        rescue
          # If YAML parsing fails, treat as string
          config[key] = value
        end
        
        save_config(config)
      end

      def add(key, value)
        key = key.to_sym
        config = load_config
        
        # Try to parse value as YAML for complex types
        begin
          parsed_value = YAML.load(value)
        rescue
          # If YAML parsing fails, treat as string
          parsed_value = value
        end
        
        # Handle different types
        if config[key].is_a?(Array)
          # Append to array
          config[key] << parsed_value
          puts "Added '#{parsed_value}' to #{key}"
        elsif config[key].is_a?(Hash) && parsed_value.is_a?(Hash)
          # Merge with hash
          config[key] = config[key].deep_merge(parsed_value)
          puts "Merged hash into #{key}"
        elsif config[key].nil?
          # Create new array or hash based on value type
          if parsed_value.is_a?(Hash)
            config[key] = parsed_value
            puts "Created new hash for #{key}"
          else
            config[key] = [parsed_value]
            puts "Created new array for #{key} with '#{parsed_value}'"
          end
        else
          puts "Cannot add to #{key} (type: #{config[key].class})"
          exit 1
        end
        
        save_config(config)
      end

      def remove(key, value)
        key = key.to_sym
        config = load_config
        
        # Try to parse value as YAML for complex types
        begin
          parsed_value = YAML.load(value)
        rescue
          # If YAML parsing fails, treat as string
          parsed_value = value
        end
        
        # Handle different types
        if config[key].is_a?(Array)
          # Remove from array
          if config[key].include?(parsed_value)
            config[key].delete(parsed_value)
            puts "Removed '#{parsed_value}' from #{key}"
          else
            puts "Value '#{parsed_value}' not found in #{key}"
          end
        elsif config[key].is_a?(Hash) && parsed_value.is_a?(Hash)
          # Remove keys from hash
          removed_keys = []
          parsed_value.each_key do |k|
            if config[key].key?(k)
              config[key].delete(k)
              removed_keys << k
            end
          end
          if removed_keys.any?
            puts "Removed keys #{removed_keys.join(', ')} from #{key}"
          else
            puts "No matching keys found in #{key}"
          end
        elsif config[key].nil?
          puts "Key '#{key}' not found in configuration"
          exit 1
        else
          puts "Cannot remove from #{key} (type: #{config[key].class})"
          exit 1
        end
        
        save_config(config)
      end

      def init
        if File.exist?(@config_path)
          puts "Configuration file already exists at #{@config_path}"
          puts "Use 'cleanbox config show' to view it"
        else
          default_config = {
            'host' => 'outlook.office365.com',
            'username' => 'your-email@example.com',
            'auth_type' => 'oauth2_microsoft',
            'clean_folders' => ['Work', 'Personal'],
            'whitelisted_domains' => ['example.com'],
            'list_folders' => ['Lists', 'Notifications'],
            'domain_map' => {
              'example.com' => 'Example'
            }
          }
          save_config(default_config)
          puts "Initial configuration created at #{@config_path}"
          puts "Please edit it with your actual settings"
        end
      end

      def load_config
        return {} unless File.exist?(@config_path)
        config = YAML.load_file(@config_path) || {}
        # Convert string keys to symbols for consistency with options hash
        config.transform_keys(&:to_sym)
      end

      def save_config(config)
        FileUtils.mkdir_p(File.dirname(@config_path))
        File.write(@config_path, config.to_yaml)
        puts "Configuration saved to #{@config_path}"
      end

      def handle_command(args)
        command = args.first
        
        case command
        when 'show'
          show
        when 'get'
          key = args[1]
          if key.nil?
            puts "Usage: cleanbox config get <key>"
            exit 1
          end
          get(key)
        when 'set'
          key = args[1]
          value = args[2]
          
          if key.nil? || value.blank?
            puts "Usage: cleanbox config set <key> <value>"
            puts "For complex values, edit the config file directly: #{@config_path}"
            exit 1
          end
          set(key, value)
        when 'add'
          key = args[1]
          value = args[2]
          
          if key.nil? || value.blank?
            puts "Usage: cleanbox config add <key> <value>"
            puts "This will append to arrays or merge with hashes"
            exit 1
          end
          add(key, value)
        when 'remove'
          key = args[1]
          value = args[2]
          
          if key.nil? || value.blank?
            puts "Usage: cleanbox config remove <key> <value>"
            puts "This will remove from arrays or delete keys from hashes"
            exit 1
          end
          remove(key, value)
        when 'init'
          init
        else
          puts "Unknown config command: #{command}"
          puts "Available commands: show, get, set, add, remove, init"
          exit 1
        end
      end
    end
  end 