# frozen_string_literal: true

module Reactor
  module Publishable
    extend ActiveSupport::Concern

    included do
      after_commit :reactor_schedule_events, if: :persisted?, on: :create
      after_commit :reactor_reschedule_events, if: :persisted?
    end

    module ClassMethods
      def publishes(name, options = {})
        events[name] = options
      end

      def events
        @events ||= {}
      end
    end

    def publish(name, options = {})
      Reactor::Event.publish(name, reactor_event_data(options))
    end

    private

    # @todo Optimize this by using a separate event list
    def reactor_schedule_events
      self.class.events.each do |name, options|
        next if options.include?(:watch)

        publish(name, options) if reactor_publishable?(options)
      end
    end

    # @todo Optimize this by using a separate event list
    # @todo Skip where at: nil, unset where at: changed to nil
    def reactor_reschedule_events
      self.class.events.each do |name, options|
        next unless options.include?(:watch)
        next unless previous_changes[options[:watch]]

        publish(name, options) if reactor_publishable?(options)
      end
    end

    def reactor_event_data(options)
      options[:actor]  = reactor_resolve_attribute(options[:actor]) || self
      options[:target] = options[:target] ? self : nil
      options[:at]     = reactor_resolve_attribute(options[:at])

      options.except(:watch, :enqueue_if)
    end

    def reactor_resolve_attribute(attribute)
      case attribute
      when Proc
        instance_exec(&attribute)
      when Symbol, String
        send(attribute.to_s)
      end
    end

    def reactor_publishable?(options)
      return true if options[:enqueue_if].nil?

      reactor_resolve_attribute(options[:enqueue_if])
    end
  end
end
