require 'spec_helper'

describe Hutch::ErrorHandlers::Logger do
  let(:error_handler) { Hutch::ErrorHandlers::Logger.new }

  describe '#handle' do
    let(:error) do
      double(message: 'Stuff went wrong', class: 'RuntimeError',
             backtrace: ['line 1', 'line 2'])
    end

    it 'logs three separate lines' do
      expect(Hutch::Logging.logger).to receive(:error).exactly(3).times
      error_handler.handle('1', '{}', double, error)
    end
  end
end
