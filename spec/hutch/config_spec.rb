require 'hutch/config'
require 'tempfile'

describe Hutch::Config do
  let(:new_value) { 'not-localhost' }

  before do
    Hutch::Config.clear!
  end

  describe '.get' do
    context 'for valid attributes' do
      subject { Hutch::Config.get(:mq_host) }

      context 'with no overridden value' do
        it { is_expected.to eq('127.0.0.1') }
      end

      context 'with an overridden value' do
        before  { allow(Hutch::Config).to receive_messages(user_config: { mq_host: new_value }) }
        it { is_expected.to eq(new_value) }
      end
    end

    context 'for invalid attributes' do
      let(:invalid_get) { ->{ Hutch::Config.get(:invalid_attr) } }
      specify { expect(invalid_get).to raise_error Hutch::UnknownAttributeError }
    end
  end

  describe '.set' do
    context 'for valid attributes' do
      before  { Hutch::Config.set(:mq_host, new_value) }
      subject { Hutch::Config.user_config[:mq_host] }

      context 'sets value in user config hash' do
        it { is_expected.to eq(new_value) }
      end
    end

    context 'for invalid attributes' do
      let(:invalid_set) { ->{ Hutch::Config.set(:invalid_attr, new_value) } }
      specify { expect(invalid_set).to raise_error Hutch::UnknownAttributeError }
    end
  end

  describe 'a magic getter' do
    context 'for a valid attribute' do
      it 'calls get' do
        expect(Hutch::Config).to receive(:get).with(:mq_host)
        Hutch::Config.mq_host
      end
    end

    context 'for an invalid attribute' do
      let(:invalid_getter) { ->{ Hutch::Config.invalid_attr } }
      specify { expect(invalid_getter).to raise_error NoMethodError }
    end

    context 'for an ENV-overriden value attribute' do
      around do |example|
        ENV['HUTCH_MQ_HOST'] = 'example.com'
        ENV['HUTCH_MQ_PORT'] = '10001'
        ENV['HUTCH_MQ_TLS'] = 'true'
        example.run
        ENV.delete('HUTCH_MQ_HOST')
        ENV.delete('HUTCH_MQ_PORT')
        ENV.delete('HUTCH_MQ_TLS')
      end

      it 'returns the override' do
        expect(Hutch::Config.mq_host).to eq 'example.com'
      end

      it 'returns the override for integers' do
        expect(Hutch::Config.mq_port).to eq 10001
      end

      it 'returns the override for booleans' do
        expect(Hutch::Config.mq_tls).to eq true
      end
    end
  end

  describe 'a magic setter' do
    context 'for a valid attribute' do
      it 'calls set' do
        expect(Hutch::Config).to receive(:set).with(:mq_host, new_value)
        Hutch::Config.mq_host = new_value
      end
    end

    context 'for an invalid attribute' do
      let(:invalid_setter) { ->{ Hutch::Config.invalid_attr = new_value } }
      specify { expect(invalid_setter).to raise_error NoMethodError }
    end
  end

  describe '.load_from_file' do
    let(:host) { 'broker.yourhost.com' }
    let(:username) { 'calvin' }
    let(:file) do
      Tempfile.new('configs.yaml').tap do |t|
        t.write(YAML.dump(config_data))
        t.rewind
      end
    end

    context 'when an attribute is invalid' do
      let(:config_data) { { random_attribute: 'socks' } }
      it 'raises an error' do
        expect {
          Hutch::Config.load_from_file(file)
        }.to raise_error(NoMethodError)
      end
    end

    context 'when attributes are valid' do
      let(:config_data) { { mq_host: host, mq_username: username } }

      it 'loads in the config data' do
        Hutch::Config.load_from_file(file)
        expect(Hutch::Config.mq_host).to eq host
        expect(Hutch::Config.mq_username).to eq username
      end
    end

    context 'when using ERB' do
      let(:host) { 'localhost' }
      let(:file) do
        Tempfile.new('configs.yaml').tap do |t|
          t.write(config_contents)
          t.rewind
        end
      end
      let(:config_contents) do
        <<-YAML
mq_host: 'localhost'
mq_username: '<%= "calvin" %>'
YAML
      end
      it 'loads in the config data' do
        Hutch::Config.load_from_file(file)
        expect(Hutch::Config.mq_host).to eq host
        expect(Hutch::Config.mq_username).to eq username
      end
    end
  end
end
