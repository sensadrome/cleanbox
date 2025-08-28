# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MessageActionRunner do
  let(:imap) { double('imap') }
  let(:runner) { MessageActionRunner.new(imap: imap, junk_folder: 'Junk') }
  let(:message) { create_message }

  describe '#execute' do
    context 'when decision is :move' do
      let(:decision) { { action: :move, folder: 'Work' } }

      it 'copies message to the specified folder' do
        expect(imap).to receive(:copy).with(message.seqno, 'Work')
        expect(imap).to receive(:store).with(message.seqno, '+FLAGS', [:Deleted])

        runner.execute(decision, message)
      end

      it 'adds the folder to changed_folders' do
        allow(imap).to receive(:copy)
        allow(imap).to receive(:store)

        runner.execute(decision, message)

        expect(runner.changed_folders).to include('Work')
      end
    end

    context 'when decision is :junk' do
      let(:decision) { { action: :junk } }

      it 'copies message to junk folder' do
        expect(imap).to receive(:copy).with(message.seqno, 'Junk')
        expect(imap).to receive(:store).with(message.seqno, '+FLAGS', [:Deleted])

        runner.execute(decision, message)
      end

      it 'adds junk folder to changed_folders' do
        allow(imap).to receive(:copy)
        allow(imap).to receive(:store)

        runner.execute(decision, message)

        expect(runner.changed_folders).to include('Junk')
      end
    end

    context 'when decision is :keep' do
      let(:decision) { { action: :keep } }

      it 'does not perform any IMAP operations' do
        expect(imap).not_to receive(:copy)
        expect(imap).not_to receive(:store)

        runner.execute(decision, message)
      end

      it 'does not add any folders to changed_folders' do
        runner.execute(decision, message)

        expect(runner.changed_folders).to be_empty
      end
    end

    context 'when decision has unknown action' do
      let(:decision) { { action: :unknown } }

      it 'raises an ArgumentError' do
        expect { runner.execute(decision, message) }.to raise_error(ArgumentError, 'Unknown action: unknown')
      end
    end
  end

  describe '#changed_folders' do
    it 'returns unique list of changed folders' do
      allow(imap).to receive(:copy)
      allow(imap).to receive(:store)

      # Execute multiple moves to same folder
      runner.execute({ action: :move, folder: 'Work' }, message)
      runner.execute({ action: :move, folder: 'Work' }, message)
      runner.execute({ action: :move, folder: 'Lists' }, message)

      expect(runner.changed_folders).to contain_exactly('Work', 'Lists')
    end

    it 'returns empty array when no actions executed' do
      expect(runner.changed_folders).to be_empty
    end
  end

  describe 'custom junk folder' do
    let(:runner) { MessageActionRunner.new(imap: imap, junk_folder: 'Spam') }
    let(:decision) { { action: :junk } }

    it 'uses the custom junk folder' do
      expect(imap).to receive(:copy).with(message.seqno, 'Spam')
      expect(imap).to receive(:store).with(message.seqno, '+FLAGS', [:Deleted])

      runner.execute(decision, message)
    end

    it 'tracks the custom junk folder in changed_folders' do
      allow(imap).to receive(:copy)
      allow(imap).to receive(:store)

      runner.execute(decision, message)

      expect(runner.changed_folders).to include('Spam')
    end
  end

  describe 'multiple executions' do
    before do
      allow(imap).to receive(:copy)
      allow(imap).to receive(:store)
    end

    it 'tracks all changed folders across multiple executions' do
      runner.execute({ action: :move, folder: 'Work' }, message)
      runner.execute({ action: :junk }, message)
      runner.execute({ action: :move, folder: 'Lists' }, message)
      runner.execute({ action: :keep }, message) # Should not be tracked

      expect(runner.changed_folders).to contain_exactly('Work', 'Junk', 'Lists')
    end
  end

  private

  def create_message
    mock_message = double('message')
    allow(mock_message).to receive(:seqno).and_return(123)
    allow(mock_message).to receive(:from_address).and_return('test@example.com')
    mock_message
  end
end
