require 'spec_helper'
require 'hutch/broker'

describe Hutch::Broker do
  let(:config) { deep_copy(Hutch::Config.user_config) }
  subject(:broker) { Hutch::Broker.new(config) }

  describe '#connect' do
    before { allow(broker).to receive(:set_up_amqp_connection) }
    before { allow(broker).to receive(:set_up_api_connection) }
    before { allow(broker).to receive(:disconnect) }

    it 'sets up the amqp connection' do
      expect(broker).to receive(:set_up_amqp_connection)
      broker.connect
    end

    it 'sets up the api connection' do
      expect(broker).to receive(:set_up_api_connection)
      broker.connect
    end

    it 'does not disconnect' do
      expect(broker).not_to receive(:disconnect)
      broker.connect
    end

    context 'when given a block' do
      it 'disconnects' do
        expect(broker).to receive(:disconnect).once
        broker.connect { }
      end
    end

    context 'when given a block that fails' do
      let(:exception) { Class.new(StandardError) }

      it 'disconnects' do
        expect(broker).to receive(:disconnect).once
        expect do
          broker.connect { fail exception }
        end.to raise_error(exception)
      end
    end

    context "with options" do
      let(:options) { { enable_http_api_use: false } }

      it "doesnt set up api" do
        expect(broker).not_to receive(:set_up_api_connection)
        broker.connect options
      end
    end
  end

  describe '#disconnect' do
    it 'calls close to all channels and then to the connection' do
      broker.set_up_amqp_connection

      Thread.new { @thread_channel = broker.publish_channel; sleep 5 }

      5.times { break if @thread_channel; sleep 0.1 }

      expect(@thread_channel).to receive(:close).ordered.and_call_original
      expect(broker.channel).to receive(:close).ordered.and_call_original

      expect(broker.connection).to receive(:close).ordered.and_call_original

      broker.disconnect
    end

    it 'resets connections/channels/exchanges/api_client to nil' do
      broker.set_up_amqp_connection

      t = Thread.new { @thread_channel = broker.publish_channel; sleep 5 }

      5.times { break if @thread_channel; sleep 0.1 }

      broker.disconnect

      expect(broker.connection).to be_nil
      expect(broker.channel).to be_nil
      expect(broker.exchange).to be_nil
      expect(broker.publish_channel).to be_nil
      expect(broker.api_client).to be_nil
      expect(t["hutch_broker_#{broker.object_id}"]).to be_nil # XXX hack: the key is private
    end
  end

  describe '#set_up_amqp_connection', rabbitmq: true do
    context 'with valid details' do
      before { broker.set_up_amqp_connection }
      after  { broker.disconnect }

      describe '#connection', adapter: :bunny do
        subject { super().connection }
        it { is_expected.to be_a Hutch::Adapters::BunnyAdapter }
      end

      describe '#connection', adapter: :march_hare do
        subject { super().connection }
        it { is_expected.to be_a Hutch::Adapters::MarchHareAdapter }
      end

      describe '#channel', adapter: :bunny do
        subject { super().channel }
        it { is_expected.to be_a Bunny::Channel }
      end

      describe '#channel', adapter: :march_hare do
        subject { super().channel }
        it { is_expected.to be_a MarchHare::Channel }
      end

      describe '#exchange', adapter: :bunny do
        subject { super().exchange }
        it { is_expected.to be_a Bunny::Exchange }
      end

      describe '#exchange', adapter: :march_hare do
        subject { super().exchange }
        it { is_expected.to be_a MarchHare::Exchange }
      end

      describe '#publish_channel' do
        subject { super().publish_channel }
        it { is_expected.to eq(broker.channel) }
      end
    end

    context 'when given invalid details' do
      before { config[:mq_host] = 'notarealhost' }
      let(:set_up_amqp_connection) { ->{ broker.set_up_amqp_connection } }

      specify { expect(set_up_amqp_connection).to raise_error }
    end

    context 'with channel_prefetch set' do
      let(:prefetch_value) { 1 }
      before { config[:channel_prefetch] = prefetch_value }
      after  { broker.disconnect }

      it "set's channel's prefetch", adapter: :bunny do
        expect_any_instance_of(Bunny::Channel).
          to receive(:prefetch).with(prefetch_value)
        broker.set_up_amqp_connection
      end

      it "set's channel's prefetch", adapter: :march_hare do
        expect_any_instance_of(MarchHare::Channel).
          to receive(:prefetch=).with(prefetch_value)
        broker.set_up_amqp_connection
      end
    end

    context 'with force_publisher_confirms set' do
      let(:force_publisher_confirms_value) { true }
      before { config[:force_publisher_confirms] = force_publisher_confirms_value }
      after  { broker.disconnect }

      it 'waits for confirmation', adapter: :bunny do
        expect_any_instance_of(Bunny::Channel).
          to receive(:confirm_select)
        broker.set_up_amqp_connection
      end

      it 'waits for confirmation', adapter: :march_hare do
        expect_any_instance_of(MarchHare::Channel).
          to receive(:confirm_select)
        broker.set_up_amqp_connection
      end
    end
  end

  describe '#publish_channel', rabbitmq: true do
    context 'without a valid connection' do
      it 'returns nil' do
        expect(broker.publish_channel).to be_nil
      end
    end

    context 'with a valid connection' do
      before { broker.set_up_amqp_connection }
      after  { broker.disconnect }

      context 'with force_publisher_confirms set' do
        let(:force_publisher_confirms_value) { true }
        before { config[:force_publisher_confirms] = force_publisher_confirms_value }

        it 'waits for confirmation', adapter: :bunny do
          expect_any_instance_of(Bunny::Channel).to receive(:confirm_select)

          Thread.new { broker.publish_channel }.join
        end

        it 'waits for confirmation', adapter: :march_hare do
          expect_any_instance_of(MarchHare::Channel).to receive(:confirm_select)

          Thread.new { broker.publish_channel }.join
        end
      end
    end
  end

  describe '#exchange' do
    context 'without a valid connection' do
      it 'returns nil' do
        expect(broker.exchange).to be_nil
      end
    end

    context 'with a valid connection' do
      it 'is declared through the publish_channel' do
        ch = double('Publish Channel')

        expect(broker).to receive(:publish_channel).and_return(ch)
        expect(ch).to receive(:topic)

        broker.exchange
      end
    end
  end

  describe '#set_up_api_connection', rabbitmq: true do
    context 'with valid details' do
      before { broker.set_up_api_connection }
      after  { broker.disconnect }

      describe '#api_client' do
        subject { super().api_client }
        it { is_expected.to be_a CarrotTop }
      end
    end

    context 'when given invalid details' do
      before { config[:mq_api_host] = 'notarealhost' }
      after  { broker.disconnect }
      let(:set_up_api_connection) { ->{ broker.set_up_api_connection } }

      specify { expect(set_up_api_connection).to raise_error }
    end
  end

  describe '#queue' do
    let(:channel) { double('Channel') }
    let(:arguments) { { foo: :bar } }
    before { allow(broker).to receive(:channel) { channel } }

    it 'applies a global namespace' do
      config[:namespace] = 'mirror-all.service'
      expect(broker.channel).to receive(:queue) do |*args|
        args.first == ''
        args.last == arguments
      end
      broker.queue('test', arguments)
    end
  end

  describe '#bindings', rabbitmq: true do
    around { |example| broker.connect { example.run } }
    subject { broker.bindings }

    context 'with no bindings' do
      describe '#keys' do
        subject { super().keys }
        it { is_expected.not_to include 'test' }
      end
    end

    context 'with a binding' do
      around do |example|
        queue = broker.queue('test').bind(broker.exchange, routing_key: 'key')
        example.run
        queue.unbind(broker.exchange, routing_key: 'key').delete
      end

      it { is_expected.to include({ 'test' => ['key'] }) }
    end
  end

  describe '#bind_queue' do

    around { |example| broker.connect { example.run } }

    let(:routing_keys) { %w( a b c ) }
    let(:queue) { double('Queue', bind: nil, unbind: nil, name: 'consumer') }
    before { allow(broker).to receive(:bindings).and_return('consumer' => ['d']) }

    it 'calls bind for each routing key' do
      routing_keys.each do |key|
        expect(queue).to receive(:bind).with(broker.exchange, routing_key: key)
      end
      broker.bind_queue(queue, routing_keys)
    end

    it 'calls unbind for each redundant existing binding' do
      expect(queue).to receive(:unbind).with(broker.exchange, routing_key: 'd')
      broker.bind_queue(queue, routing_keys)
    end

    context '(rabbitmq integration test)', rabbitmq: true do
      let(:queue) { broker.queue('consumer') }
      let(:routing_key) { 'key' }

      before { allow(broker).to receive(:bindings).and_call_original }
      before { queue.bind(broker.exchange, routing_key: 'redundant-key') }
      after { queue.unbind(broker.exchange, routing_key: routing_key).delete }

      it 'results in the correct bindings' do
        broker.bind_queue(queue, [routing_key])
        expect(broker.bindings).to include({ queue.name => [routing_key] })
      end
    end
  end

  describe '#wait_on_threads' do
    let(:thread) { double('Thread') }
    before { allow(broker).to receive(:work_pool_threads).and_return(threads) }

    context 'when all threads finish within the timeout' do
      let(:threads) { [double(join: thread), double(join: thread)] }
      specify { expect(broker.wait_on_threads(1)).to be_truthy }
    end

    context 'when timeout expires for one thread' do
      let(:threads) { [double(join: thread), double(join: nil)] }
      specify { expect(broker.wait_on_threads(1)).to be_falsey }
    end
  end

  describe '#stop', adapter: :bunny do
    let(:thread_1) { double('Thread') }
    let(:thread_2) { double('Thread') }
    let(:work_pool) { double('Bunny::ConsumerWorkPool') }
    let(:config) { { graceful_exit_timeout: 2 } }

    before do
      allow(broker).to receive(:channel_work_pool).and_return(work_pool)
    end

    it 'gracefully stops the work pool' do
      expect(work_pool).to receive(:shutdown)
      expect(work_pool).to receive(:join).with(2)
      expect(work_pool).to receive(:kill)

      broker.stop
    end
  end

  describe '#stop', adapter: :march_hare do
    let(:channel) { double('MarchHare::Channel')}

    before do
      allow(broker).to receive(:channel).and_return(channel)
    end

    it 'gracefully stops the channel' do
      expect(channel).to receive(:close)

      broker.stop
    end
  end

  describe '#publish' do
    context 'with a valid connection' do
      before { broker.set_up_amqp_connection }
      after  { broker.disconnect }

      it 'publishes to the exchange' do
        expect(broker.exchange).to receive(:publish).once
        broker.publish('test.key', 'message')
      end

      it 'sets default properties' do
        expect(broker.exchange).to receive(:publish).with(
          JSON.dump("message"),
          hash_including(
            persistent: true,
            routing_key: 'test.key',
            content_type: 'application/json'
          )
        )

        broker.publish('test.key', 'message')
      end

      it 'allows passing message properties' do
        expect(broker.exchange).to receive(:publish).once
        broker.publish('test.key', 'message', {expiration: "2000", persistent: false})
      end

      context 'when there are global properties' do
        context 'as a hash' do
          before do
            allow(Hutch).to receive(:global_properties).and_return(app_id: 'app')
          end

          it 'merges the properties' do
            expect(broker.exchange).
              to receive(:publish).with('"message"', hash_including(app_id: 'app'))
            broker.publish('test.key', 'message')
          end
        end

        context 'as a callable object' do
          before do
            allow(Hutch).to receive(:global_properties).and_return(proc { { app_id: 'app' } })
          end

          it 'calls the proc and merges the properties' do
            expect(broker.exchange).
              to receive(:publish).with('"message"', hash_including(app_id: 'app'))
            broker.publish('test.key', 'message')
          end
        end
      end

      context 'with force_publisher_confirms not set in the config' do
        it 'does not wait for confirms on the channel', adapter: :bunny do
          expect_any_instance_of(Bunny::Channel).
            to_not receive(:wait_for_confirms)
          broker.publish('test.key', 'message')
        end

        it 'does not wait for confirms on the channel', adapter: :march_hare do
          expect_any_instance_of(MarchHare::Channel).
            to_not receive(:wait_for_confirms)
          broker.publish('test.key', 'message')
        end
      end

      context 'with force_publisher_confirms set in the config' do
        let(:force_publisher_confirms_value) { true }

        before do
          config[:force_publisher_confirms] = force_publisher_confirms_value
        end

        it 'waits for confirms on the channel', adapter: :bunny do
          expect_any_instance_of(Bunny::Channel).
            to receive(:wait_for_confirms)
          broker.publish('test.key', 'message')
        end

        it 'waits for confirms on the channel', adapter: :march_hare do
          expect_any_instance_of(MarchHare::Channel).
            to receive(:wait_for_confirms)
          broker.publish('test.key', 'message')
        end
      end

      context 'with multiple threads' do
        it 'uses different channels per thread' do
          main_publish_channel  = broker.publish_channel
          main_exchange = broker.exchange

          expect(main_exchange).to receive(:publish)

          broker.publish('test.key', 'message')

          Thread.new do
            expect(broker.publish_channel).not_to  eq(main_publish_channel)
            expect(broker.exchange).not_to eq(main_exchange)
            expect(broker.exchange.channel).not_to eq(main_exchange.channel)

            expect(broker.exchange).to receive(:publish)
            broker.publish('test.key', 'message')
          end.join
        end
      end
    end

    context 'without a valid connection' do
      it 'raises an exception' do
        expect { broker.publish('test.key', 'message') }.
          to raise_exception(Hutch::PublishError)
      end

      it 'logs an error' do
        expect(broker.logger).to receive(:error)
        broker.publish('test.key', 'message') rescue nil
      end
    end
  end
end
