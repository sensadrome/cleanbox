# frozen_string_literal: true

require 'i18n'

module CLI
  # Handles all user input and prompting functionality for CLI commands
  module InteractivePrompts
    def prompt(message, default: nil, secret: false)
      loop do
        print_prompt(message, default)
        input = read_user_input(secret)
        input = apply_default(input, default)

        return input unless block_given?
        return input if yield(input)

        puts I18n.t('cli.errors.invalid_input')
      end
    end

    def prompt_with_default(message, default, &block)
      if block_given?
        prompt(message, default: default, &block)
      else
        prompt(message, default: default) { |input| !input.empty? }
      end
    end

    def prompt_choice(message, choices)
      puts I18n.t('cli.prompts.choice_header', message: message)
      choices.each_with_index do |choice, index|
        puts I18n.t('cli.prompts.choice_option', index: index + 1, label: choice[:label])
      end

      make_choice(choices)
    end

    private

    def print_prompt(message, default)
      if default
        print "#{message} [#{default}]: "
      else
        print "#{message}: "
      end
    end

    def read_user_input(secret)
      if secret
        read_secret_input
      else
        gets.chomp
      end
    end

    def read_secret_input
      system('stty -echo')
      result = gets.chomp
      system('stty echo')
      puts
      result
    end

    def apply_default(input, default)
      return default if input.empty? && default

      input
    end

    def make_choice(choices)
      loop do
        print "Choice (1-#{choices.length}): "
        choice = gets.chomp.to_i

        return choices[choice - 1][:key] if choice.between?(1, choices.length)

        puts I18n.t('cli.errors.invalid_choice', max: choices.length)
      end
    end
  end
end 