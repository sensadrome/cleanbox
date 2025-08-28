# frozen_string_literal: true

require 'i18n'

# Load locale files
I18n.load_path << Dir[File.expand_path('config/locales/*.yml')]

# Set default locale
I18n.default_locale = :en
I18n.available_locales = [:en] 