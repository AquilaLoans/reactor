# frozen_string_literal: true

require 'spec_helper'

class Auction < ApplicationRecord
  on_event :bid_made do |event|
    event.target.update_column :status, 'first_bid_made'
  end

  on_event :puppy_delivered, :ring_bell
  on_event :puppy_delivered, handler_name: :do_nothing_handler do |event|
  end
  on_event :any_event, ->(_event) { puppies! }
  on_event :pooped, :pick_up_poop, delay: 5.minutes
  on_event '*' do |event|
    event.actor.more_puppies! if event.name == 'another_event'
  end

  on_event :a_high_frequency_event, deprecated: true do |_event|
    raise 'hell'
  end

  on_event :event_with_ui_bound,
           sidekiq_options: { queue: 'highest_priority', retry: false } do |_event|
    speedily_execute!
  end

  def self.ring_bell(event)
    "ring ring! #{event}"
  end
end

module MyNamespace
  class MyClass
    include Reactor::Subscribable
    on_event :rain, :umbrella
  end

  def self.umbrella
    puts 'get an umbrella'
  end
end

class KittenMailer < ActionMailer::Base
  include Reactor::Subscribable

  on_event :auction, handler_name: 'auction' do |_event|
    @@fired = true
  end

  on_event :kitten_streaming do |event|
    kitten_livestream(event)
  end

  def kitten_livestream(_event)
    mail(
      to: 'admin@kittens.com',
      from: 'test@kittens.com',
      subject: 'Livestreaming kitten videos'
    ) do |format|
      format.text { 'Your favorite kittens are now live!' }
    end
  end
end

class TestModeAuction < ApplicationRecord
  on_event :test_puppy_delivered, ->(_event) { 'success' }
end

describe Reactor::Subscribable do
  let(:scheduled) { Sidekiq::ScheduledSet.new }

  describe 'on_event' do
    it 'binds block of code statically to event being fired' do
      expect_any_instance_of(Auction).to receive(:update_column).with(:status, 'first_bid_made')
      Reactor::Event.publish(:bid_made, target: Auction.create!(start_at: 10.minutes.from_now))
    end

    describe 'building uniquely named subscriber handler classes' do
      it 'adds a static subscriber to the global lookup constant' do
        expect(Reactor::SUBSCRIBERS['puppy_delivered'][0]).to eq(Reactor::StaticSubscribers::Auction::PuppyDeliveredHandler)
        expect(Reactor::SUBSCRIBERS['puppy_delivered'][1]).to eq(Reactor::StaticSubscribers::Auction::DoNothingHandler)
      end

      it 'adds a static subscriber for namespaced classes at the same module depth' do
        expect(Reactor::SUBSCRIBERS['rain'][0]).to eq(Reactor::StaticSubscribers::MyNamespace::MyClass::RainHandler)
      end
    end

    describe 'binding symbol of class method' do
      let(:pooped_handler) { Reactor::StaticSubscribers::Auction::PoopedHandler }

      it 'fires on event' do
        expect(Reactor::StaticSubscribers::Auction::WildcardHandler)
          .to receive(:perform_async).and_call_original
        expect(Auction).to receive(:ring_bell)
        Reactor::Event.publish(:puppy_delivered)
      end

      it 'fires perform_async when true / default' do
        Reactor::Event.publish(:puppy_delivered)
      end

      it 'can be delayed' do
        expect(Auction).to receive(:pick_up_poop)
        expect(pooped_handler).to receive(:perform_in).with(5.minutes, 'pooped', anything).and_call_original
        Reactor::Event.perform('pooped', {})
      end
    end

    it 'binds proc' do
      expect(Auction).to receive(:puppies!)
      Reactor::Event.publish(:any_event)
    end

    it 'accepts wildcard event name' do
      expect_any_instance_of(Auction).to receive(:more_puppies!)
      Reactor::Event.publish(:another_event, actor: Auction.create!(start_at: 5.minutes.from_now))
    end

    # ran into a case where if a class for the event name already exists,
    # it will re-open that class instead of putting it in the proper namespace
    # which raised a NoMethodError for perform_where_needed
    it 'handles names that already exist in the global namespace' do
      expect(::Auction).to be_a(Class)
      # have to ensure multiple subscribers are loaded
      expect(KittenMailer).to be_a(Class)
      expect { Reactor::Event.publish(:auction) }.not_to raise_error
    end

    describe 'deprecate flag for high-frequency events in production deployments' do
      it 'doesnt enqueue subscriber worker when true' do
        # so subscriber can be safely deleted in next deploy
        expect do
          Reactor::Event.publish(:a_high_frequency_event)
        end.to_not raise_exception
      end
    end

    describe 'passing sidekiq_options through to Sidekiq' do
      it 'passes options to Sidekiq API' do
        expect(Reactor::StaticSubscribers::Auction::EventWithUiBoundHandler.get_sidekiq_options)
          .to eql('queue' => 'highest_priority', 'retry' => false)
      end

      it 'keeps default options when none supplied' do
        expect(Reactor::StaticSubscribers::Auction::WildcardHandler.get_sidekiq_options)
          .to eql('queue' => 'default', 'retry' => true)
      end
    end

    describe 'overriding queue options with ENV variable to isolate cascade between processes' do
      before { ENV['REACTOR_QUEUE'] = 'bulk' }
      after { ENV.delete('REACTOR_QUEUE') }

      specify do
        expect_any_instance_of(Reactor::StaticSubscribers::Auction::WildcardHandler)
          .to receive(:perform)

        expect(Reactor::StaticSubscribers::Auction::WildcardHandler).to receive(:set)
          .with(hash_including(queue: 'bulk')).and_call_original

        Reactor::Event.publish(:puppy_delivered)
      end
    end

    describe '#perform' do
      it 'performs normally when specifically enabled' do
        allow_reactor_subscriber(TestModeAuction) do
          expect(Reactor::StaticSubscribers::TestModeAuction::TestPuppyDeliveredHandler.new.perform(:name, {})).not_to eq(:__perform_aborted__)
          Reactor::Event.publish(:test_puppy_delivered)
        end
      end
    end
  end

  describe 'mailers', type: :mailer do
    def deliveries
      ActionMailer::Base.deliveries
    end

    it 'sends an email from a method on_event', focus: true do
      expect { Reactor::Event.publish(:kitten_streaming) }.to change { deliveries.count }.by(1)
    end
  end
end
