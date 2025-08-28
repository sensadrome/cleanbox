# frozen_string_literal: true

# Example script showing how to use CleanboxConsole programmatically
# This is useful for scripting or when you want to use Cleanbox in your own code

# Add the lib directory to the load path
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

# Load the console module
require 'console'

puts "Cleanbox Console Example"
puts "========================"

# Example 1: Connect with custom configuration
puts "\n1. Connecting with custom config..."
begin
  cleanbox = CleanboxConsole.connect(
    host: 'imap.example.com',
    username: 'user@example.com',
    # Add other options as needed
    pretend: true,  # Don't actually move messages
    level: 'debug'
  )
  
  puts "✅ Connected successfully!"
  
  # Show configuration
  puts "\nCurrent config:"
  puts CleanboxConsole.config
  
  # Show folders
  puts "\nAvailable folders:"
  CleanboxConsole.folders
  
  # Show message counts
  puts "\nMessage counts:"
  puts CleanboxConsole.message_counts
  
  # Clean inbox (in pretend mode)
  puts "\nCleaning inbox (pretend mode)..."
  CleanboxConsole.clean_inbox!
  
rescue => e
  puts "❌ Connection failed: #{e.message}"
  puts "This is expected if you don't have a real email server configured"
end

# Example 2: Using the convenience methods
puts "\n2. Using convenience methods..."
puts "You can also use 'cb' or 'cleanbox' for quick access:"

# These would work if you had a connection:
# cb.folders
# cleanbox.message_counts

puts "Example commands:"
puts "  cb.folders"
puts "  cb.message_counts"
puts "  cb.clean_inbox!"
puts "  cb.file_messages!"
puts "  cb.unjunk!"

# Example 3: Working with the console module directly
puts "\n3. Console module methods:"
puts "Available methods:"
puts "  CleanboxConsole.connect()"
puts "  CleanboxConsole.quick_connect()"
puts "  CleanboxConsole.config"
puts "  CleanboxConsole.folders"
puts "  CleanboxConsole.help"

puts "\nFor interactive use, run:"
puts "  ./bin/console        # Console (tries Pry first, falls back to IRB)"
puts "  ./bin/console -c /path/to/config.yml  # With custom config"
puts "\nOr start irb/pry and require the console:"
puts "  require_relative 'lib/console'"
puts "  CleanboxConsole.help" 