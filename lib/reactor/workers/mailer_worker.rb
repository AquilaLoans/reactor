# frozen_string_literal: true

# MailerWorker has a bit more to do than EventWorker. It has to run the event, then if the
# output is a Mail::Message or the like it needs to deliver it like ActionMailer would
module Reactor
  module Workers
    class MailerWorker
      include Reactor::Workers::Configuration

      def perform(name, data)
        raise_unconfigured! unless configured?
        return :__perform_aborted__ unless should_perform?

        event              = Reactor::Event.new(data)
        mailer             = source.new
        mailer.action_name = "#{name}_email"

        mailer.run_callbacks(:process_action) do
          if action.is_a?(Symbol)
            mailer.public_send(action, event)
          else
            mailer.instance_exec(event, &action)
          end
        end

        if mailer.instance_variable_get(:@_mail_was_called) && deliverable?(mailer.message)
          deliver(mailer.message)
        else
          mailer.message
        end
      end

      def deliver(message)
        if message.respond_to?(:deliver_now)
          # Rails 4.2/5.0
          message.deliver_now
        else
          # Rails 3.2/4.0/4.1 + Generic Mail::Message
          message.deliver
        end
      end

      def deliverable?(message)
        message.respond_to?(:deliver_now) || message.respond_to?(:deliver)
      end
    end
  end
end
