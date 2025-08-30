# frozen_string_literal: true

RSpec.shared_context 'capture output' do
  let(:captured_output) { StringIO.new }
end

RSpec.configure do |config|
  config.include_context 'capture output'

  config.around(:each) do |ex|
    orig_out = $stdout
    $stdout = captured_output
    ex.run
  ensure
    $stdout = orig_out
  end
end
