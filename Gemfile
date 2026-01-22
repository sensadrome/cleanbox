# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# gem "rails"

gem 'dotenv'
gem 'gmail_xoauth'
gem 'i18n'
gem 'mail'
gem 'pry', require: false
gem 'pry-byebug', require: false

# Console-only tools
group :console do
  gem 'html2markdown'
  gem 'awesome_print'
end

# gem 'selenium-webdriver'

# Testing gems
group :test, :development do
  gem 'climate_control'
  gem 'rspec'
  gem 'rspec-mocks'
  gem 'simplecov', require: false
  gem 'vcr'
  gem 'webmock'
end
