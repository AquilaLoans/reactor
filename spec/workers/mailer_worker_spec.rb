# frozen_string_literal: true

require 'spec_helper'

class MailerSubscriber < ActionMailer::Base
  include Reactor::Subscribable

  def fire_mailer(_event)
    mail subject: 'Here is a mailer',
         to: 'reactor@hired.com',
         from: 'test+reactor@hired.com',
         body: 'an example email body'
  end

  on_event :test_email do |_event|
    mail subject: 'Here is a mailer',
         to: 'reactor@hired.com',
         from: 'test+reactor@hired.com',
         body: 'an example email body'
  end
end

class MyMailerWorker < Reactor::Workers::MailerWorker
  self.source = MailerSubscriber
  self.action = :fire_mailer
  self.delay  = 0
  self.deprecated = false
end

class MyBlockMailerWorker < Reactor::Workers::MailerWorker
  self.source = MailerSubscriber
  self.delay  = 0
  self.action = ->(event) { fire_mailer(event) }
  self.deprecated = false
end

describe Reactor::Workers::MailerWorker do
  let(:klass) { MyMailerWorker }
  let(:event_name) { :email_worker }
  let(:event_data) { Hash[some_example: :event_data] }
  subject { klass.new.perform(event_name, event_data) }

  before do
    allow_any_instance_of(klass).to receive(:should_perform?).and_return(true)
  end

  it_behaves_like 'configurable subscriber worker'

  it 'sends an email from symbol method name' do
    expect { subject }.to change { ActionMailer::Base.deliveries.count }.by(1)
  end

  context 'for a block subscription' do
    let(:klass) { MyBlockMailerWorker }

    it 'sends an email from the block' do
      expect { subject }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end

  context 'for an inline event block' do
    it 'sends an email from the block' do
      expect do
        Reactor::Event.publish(:test_email, actor: nil)
      end.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end
end
