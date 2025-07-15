# frozen_string_literal: true

require 'logger'
require 'yaml'

module Analysis
  class DomainMapper
    DEFAULT_DOMAIN_RULES_FILE = File.expand_path('../../../config/domain_rules.yml', __FILE__)
    USER_DOMAIN_RULES_FILE = File.expand_path('~/.cleanbox/domain_rules.yml')
    
    def initialize(folders, logger: nil)
      @folders = folders
      @logger = logger || Logger.new(STDOUT)
      @mappings = {}
    end
    
    def generate_mappings
      list_folders = @folders.select { |f| f[:categorization] == :list }
      
      list_folders.each do |folder|
        folder[:domains].each do |domain|
          related_domains = find_related_domains(domain)
          related_domains.each do |related_domain|
            unless has_folder_for_domain?(related_domain)
              @mappings[related_domain] = folder[:name]
            end
          end
        end
        
        # Add suggested mappings based on folder name
        suggested_domains = suggest_domains_for_folder(folder[:name])
        suggested_domains.each do |domain|
          unless @mappings.key?(domain) || has_folder_for_domain?(domain)
            @mappings[domain] = folder[:name]
          end
        end
      end
      
      @mappings
    end
    
    private
    
    def domain_rules
      @domain_rules ||= load_domain_rules
    end
    
    def load_domain_rules
      # Try user custom file first
      if File.exist?(USER_DOMAIN_RULES_FILE)
        @logger.debug "Loading domain rules from user file: #{USER_DOMAIN_RULES_FILE}"
        load_yaml_file(USER_DOMAIN_RULES_FILE)
      # Fall back to repo default file
      elsif File.exist?(DEFAULT_DOMAIN_RULES_FILE)
        @logger.debug "Loading domain rules from default file: #{DEFAULT_DOMAIN_RULES_FILE}"
        load_yaml_file(DEFAULT_DOMAIN_RULES_FILE)
      # Fall back to empty rules with warning
      else
        @logger.warn "No domain rules files found. Domain mapping will be disabled."
        @logger.warn "Run 'cleanbox config init-domain-rules' to create a default configuration."
        { 'domain_patterns' => {}, 'folder_patterns' => {} }
      end
    end
    
    def domain_mappings
      domain_rules['domain_patterns'] || {}
    end
    
    def folder_suggestions
      domain_rules['folder_patterns'] || {}
    end
    
    def load_yaml_file(file_path)
      YAML.load_file(file_path)
    rescue => e
      @logger.warn "Failed to load domain rules from #{file_path}: #{e.message}"
      { 'domain_patterns' => {}, 'folder_patterns' => {} }
    end
    
    def find_related_domains(domain)
      domain_lower = domain.downcase
      
      domain_mappings.each do |pattern, related_domains|
        if domain_lower.match?(pattern)
          return related_domains
        end
      end
      
      [] # No known variations
    end
    
    def suggest_domains_for_folder(folder_name)
      folder_lower = folder_name.downcase
      
      folder_suggestions.each do |pattern, suggested_domains|
        if folder_lower.match?(pattern)
          return suggested_domains
        end
      end
      
      [] # No known suggestions for this folder
    end
    
    def has_folder_for_domain?(domain)
      @folders.any? do |folder|
        folder[:domains].include?(domain)
      end
    end
  end
end 