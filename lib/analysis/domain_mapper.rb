# frozen_string_literal: true

require 'logger'

module Analysis
  class DomainMapper
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
    
    def find_related_domains(domain)
      case domain.downcase
      when /github\.com/
        ['githubusercontent.com', 'github.io', 'githubapp.com']
      when /facebook\.com/
        ['facebookmail.com', 'fb.com', 'messenger.com']
      when /amazon\.(com|co\.uk|de|fr|ca|com\.au)/
        # If we find any Amazon domain, suggest other Amazon domains
        ['amazon.com', 'amazon.co.uk', 'amazon.de', 'amazon.fr', 'amazon.ca', 'amazon.com.au']
      when /ebay\.(com|co\.uk|de|fr|com\.au)/
        # If we find any eBay domain, suggest other eBay domains
        ['ebay.com', 'ebay.co.uk', 'ebay.de', 'ebay.fr', 'ebay.com.au']
      when /paypal\.(com|co\.uk|de|fr)/
        # If we find any PayPal domain, suggest other PayPal domains
        ['paypal.com', 'paypal.co.uk', 'paypal.de', 'paypal.fr']
      when /apple\.com/
        ['email.apple.com', 'appleid.apple.com']
      when /shopify\.com/
        ['shopifyemail.com', 'm.shopifyemail.com']
      when /stripe\.com/
        ['stripe.com', 'mail.stripe.com']
      when /linkedin\.com/
        ['linkedinmail.com']
      when /twitter\.com/
        ['t.co']
      when /instagram\.com/
        ['mail.instagram.com']
      when /netflix\.com/
        ['members.netflix.com']
      when /spotify\.com/
        ['email.spotify.com']
      when /google\.com/
        ['accounts.google.com', 'mail.google.com']
      when /microsoft\.com/
        ['outlook.com', 'office365.com']
      else
        [] # No known variations
      end
    end
    
    def suggest_domains_for_folder(folder_name)
      case folder_name.downcase
      when /^facebook$/i
        ['facebookmail.com', 'fb.com', 'messenger.com', 'developers.facebook.com']
      when /^github$/i
        ['githubusercontent.com', 'github.io', 'githubapp.com']
      when /^amazon$/i
        ['amazon.co.uk', 'amazon.de', 'amazon.fr', 'amazon.ca', 'amazon.com.au']
      when /^apple$/i
        ['appleid.apple.com', 'email.apple.com', 'apple.com']
      when /^ebay$/i
        ['ebay.co.uk', 'ebay.de', 'ebay.fr', 'ebay.com.au']
      when /^paypal$/i
        ['paypal.co.uk', 'paypal.de', 'paypal.fr']
      when /^linkedin$/i
        ['linkedin.com', 'linkedinmail.com']
      when /^twitter$/i
        ['twitter.com', 't.co']
      when /^instagram$/i
        ['instagram.com', 'mail.instagram.com']
      when /^netflix$/i
        ['netflix.com', 'members.netflix.com']
      when /^spotify$/i
        ['spotify.com', 'email.spotify.com']
      when /^youtube$/i
        ['youtube.com', 'noreply@youtube.com']
      when /^google$/i
        ['google.com', 'accounts.google.com', 'mail.google.com']
      when /^microsoft$/i, /^outlook$/i
        ['microsoft.com', 'outlook.com', 'office365.com']
      else
        [] # No known suggestions for this folder
      end
    end
    
    def has_folder_for_domain?(domain)
      @folders.any? do |folder|
        folder[:domains].include?(domain)
      end
    end
  end
end 