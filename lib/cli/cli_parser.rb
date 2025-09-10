# frozen_string_literal: true

require 'optparse'

module CLI
  class CLIParser
    def initialize
      @options = {}
    end

    def parse!
      OptionParser.new do |opts|
        setup_banner(opts)
        setup_global_options(opts)
        setup_connection_options(opts)
        setup_processing_options(opts)
        setup_commands_help(opts)
      end.parse!
      @options
    end

    private

    def setup_banner(opts)
      opts.banner = 'Usage: cleanbox [options] [command]'
    end

    def setup_global_options(opts)
      opts.on('-v', '--verbose', 'Run verbosely') do |v|
        @options[:verbose] = v
        @options[:level] = 'debug'
      end

      opts.on('-h', '--help', 'Prints this help') do
        puts opts
        exit
      end

      opts.on('-n', '--pretend', 'Only show what would happen') do
        @options[:pretend] = true
      end

      opts.on('-c', '--config CONFIG_FILE', 'Specify configuration file (default: ~/.cleanbox.yml)') do |val|
        @options[:config_file] = val
      end

      opts.on('-D', '--data-dir DATA_DIR', 'Specify data directory for config, cache, and logs') do |val|
        @options[:data_dir] = val
      end

      loglevel_help = 'log level, should be one of debug, info, warn, error'
      opts.on('-L', '--level loglevel', loglevel_help) do |value|
        @options[:level] = value
      end

      logfile_help = 'Specify log file (defaults to STDOUT)'
      opts.on('-l', '--log-file LOGFILE', logfile_help) do |val|
        @options[:log_file] = val
      end
    end

    def setup_connection_options(opts)
      host_help = "Set the IMAP hostname (default '#{@options[:host]}'"
      opts.on('-H', '--host HOST', host_help) do |val|
        @options[:host] = val
      end

      opts.on('-u', '--user USERNAME', 'Set IMAP username') do |val|
        @options[:username] = val
      end

      opts.on('-p', '--password PASSWORD', 'Set IMAP password') do |val|
        @options[:password] = val
      end

      opts.on('-C', '--client_id CLIENT_ID', 'Set client id for ouath2 token') do |val|
        @options[:client_id] = val
      end

      opts.on('-S', '--client_secret SECRET', 'Set client secret for ouath2 token') do |val|
        @options[:client_secret] = val
      end

      opts.on('-T', '--tenant_id TENANT_ID', 'Set tenant id for ouath2 token') do |val|
        @options[:tenant_id] = val
      end
    end

    def setup_processing_options(opts)
      valid_from_help = 'Use addresses found since this date (default 1 year ago)'
      opts.on('-f', '--valid-from DATE', valid_from_help) do |val|
        @options[:valid_from] = val
      end

      since_help = 'Operate on emails found since this date (default 1 year ago)'
      opts.on('-s', '--since DATE', since_help) do |val|
        @options[:since] = val
      end

      since_help = 'Operate on emails found less than MONTHS old'
      opts.on('-m', '--since-months MONTHS', since_help) do |val|
        @options[:since_months] = val
      end

      since_help = 'Operate on ALL emails (for filing, unjunking commands)'
      opts.on('-A', '--all', since_help) do
        @options[:all_messages] = true
      end

      opts.on('-F', '--file-from FOLDER',
              'Limit sender map to addresses found in FOLDER (can use multiple times)') do |folder|
        @options[:file_from_folders] ||= []
        @options[:file_from_folders] << folder
      end

      # Analysis options
      opts.on('--brief', 'Show high-level summary only (for analysis commands)') do
        @options[:brief] = true
      end

      opts.on('--detailed', 'Show detailed analysis with examples (for analysis commands)') do
        @options[:detailed] = true
      end
    end

    def setup_commands_help(opts)
      opts.separator ''
      opts.separator 'Commands:'
      opts.separator ''
      opts.separator '  auth'
      opts.separator '    manage authentication (setup, test, show, reset)'
      opts.separator ''
      opts.separator '  setup'
      opts.separator '    interactive setup wizard - analyzes your email and configures Cleanbox'
      opts.separator ''
      opts.separator '  analyze'
      opts.separator '    analyze email patterns and provide recommendations'
      opts.separator ''
      opts.separator '  list'
      opts.separator '    show the mapping of email addresses to folders for filing'
      opts.separator ''
      opts.separator '  file'
      opts.separator '    file any message in the Inbox based on folders (or FOLDER if specified)'
      opts.separator ''
      opts.separator '  unjunk'
      opts.separator '    unjunk based on mail in specified FOLDER'
      opts.separator ''
      opts.separator '  folders'
      opts.separator '    list all folders'
      opts.separator ''
      opts.separator '  blacklist'
      opts.separator '    show blacklisted email addresses'
      opts.separator ''
      opts.separator '  config'
      opts.separator '    manage configuration file'
      opts.separator ''
    end
  end
end
