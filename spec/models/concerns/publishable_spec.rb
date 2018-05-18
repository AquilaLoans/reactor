# frozen_string_literal: true

require 'spec_helper'
require 'sidekiq/testing'

class Publisher < ApplicationRecord
  belongs_to :pet

  # Publish On Create (Perform Now)
  publishes :publish_on_create

  # Publish On Create (Perform At)
  publishes :publish_on_create_with_at_lambda, at: -> { run_at }
  publishes :publish_on_create_with_at_function, at: :run_at

  # Publish On Create (Perform If & Now)
  publishes :publish_on_create_if_lambda, if: -> { should_run? }
  publishes :publish_on_create_if_function, if: :should_run?

  # Publish On Create If Enqueue (Perform Now)
  publishes :publish_on_create_if_enqueue_lambda, enqueue_if: -> { should_run? }
  publishes :publish_on_create_if_enqueue_function, enqueue_if: :should_run?

  # Publish On Update (Perform Now)
  publishes :publish_on_update, watch: :watched_column

  # Publish On Update (Perform At)
  publishes :publish_on_update_with_at_lambda, watch: :watched_column, at: -> { run_at }
  publishes :publish_on_update_with_at_function, watch: :watched_column, at: :run_at

  # Publish On Update (Perform If & Now)
  publishes :publish_on_update_if_lambda, watch: :watched_column, if: -> { should_run? }
  publishes :publish_on_update_if_function, watch: :watched_column, if: :should_run?

  # Publish On Update If Enqueue (Perform Now)
  publishes :publish_on_update_if_enqueue_lambda, watch: :watched_column, enqueue_if: -> { should_run? }
  publishes :publish_on_update_if_enqueue_function, watch: :watched_column, enqueue_if: :should_run?

  # @todo Add Specs
  # publishes :begin, at: :start_at, additional_info: 'curtis was here'
  # publishes :woof, actor: :pet, target: :self
end

describe Reactor::Publishable do
  describe 'publishes' do
    before(:each) do
      allow(Reactor::Event).to receive(:publish)
    end

    describe 'publish_on_create' do
      it 'publishes on create' do
        expect(Reactor::Event).to receive(:publish).with(:publish_on_create, anything).once

        Publisher.create!
      end

      it 'does not publish on update' do
        instance = Publisher.create!

        expect(Reactor::Event).not_to receive(:publish).with(:publish_on_create, anything)

        instance.update!(watched_column: 'NEW_VALUE')
      end
    end

    describe 'publish_on_create_with_at_lambda' do
      it 'publishes on create' do
        expect(Reactor::Event).to receive(:publish).with(:publish_on_create_with_at_lambda, anything).once

        Publisher.create!(run_at: Time.current)
      end

      it 'does not publish on update' do
        instance = Publisher.create!(run_at: Time.current)

        expect(Reactor::Event).not_to receive(:publish).with(:publish_on_create_with_at_lambda, anything)

        instance.update!(watched_column: 'NEW_VALUE')
      end
    end

    describe 'publish_on_create_with_at_function' do
      it 'publishes on create' do
        expect(Reactor::Event).to receive(:publish).with(:publish_on_create_with_at_function, anything).once

        Publisher.create!(run_at: Time.current)
      end

      it 'does not publish on update' do
        instance = Publisher.create!(run_at: Time.current)

        expect(Reactor::Event).not_to receive(:publish).with(:publish_on_create_with_at_function, anything)

        instance.update!(watched_column: 'NEW_VALUE')
      end
    end

    describe 'publish_on_create_if_lambda' do
      it 'publishes on create' do
        expect(Reactor::Event).to receive(:publish).with(:publish_on_create_if_lambda, anything).once

        Publisher.create!
      end

      it 'does not publish on update' do
        instance = Publisher.create!

        expect(Reactor::Event).not_to receive(:publish).with(:publish_on_create_if_lambda, anything)

        instance.update!(watched_column: 'NEW_VALUE')
      end
    end

    describe 'publish_on_create_if_function' do
      it 'publishes on create' do
        expect(Reactor::Event).to receive(:publish).with(:publish_on_create_if_function, anything).once

        Publisher.create!
      end

      it 'does not publish on update' do
        instance = Publisher.create!

        expect(Reactor::Event).not_to receive(:publish).with(:publish_on_create_if_function, anything)

        instance.update!(watched_column: 'NEW_VALUE')
      end
    end

    describe 'publish_on_create_if_enqueue_lambda' do
      context 'when enqueue_if is true' do
        it 'publishes on create' do
          expect(Reactor::Event).to receive(:publish).with(:publish_on_create_if_enqueue_lambda, anything).once

          Publisher.create!(should_run: true)
        end

        it 'does not publish on update' do
          instance = Publisher.create!(should_run: true)

          expect(Reactor::Event).not_to receive(:publish).with(:publish_on_create_if_enqueue_lambda, anything)

          instance.update!(watched_column: 'NEW_VALUE')
        end
      end

      context 'when enqueue_if is false' do
        it 'does not publish on create' do
          expect(Reactor::Event).not_to receive(:publish).with(:publish_on_create_if_enqueue_lambda, anything)

          Publisher.create!(should_run: false)
        end

        it 'does not publish on update' do
          instance = Publisher.create!(should_run: true)

          expect(Reactor::Event).not_to receive(:publish).with(:publish_on_create_if_enqueue_lambda, anything)

          instance.update!(should_run: false)
        end
      end
    end

    describe 'publish_on_create_if_enqueue_function' do
      context 'when enqueue_if is true' do
        it 'publishes on create' do
          expect(Reactor::Event).to receive(:publish).with(:publish_on_create_if_enqueue_function, anything).once

          Publisher.create!(should_run: true)
        end

        it 'does not publish on update' do
          instance = Publisher.create!(should_run: true)

          expect(Reactor::Event).not_to receive(:publish).with(:publish_on_create_if_enqueue_function, anything)

          instance.update!(watched_column: 'NEW_VALUE')
        end
      end

      context 'when enqueue_if is false' do
        it 'does not publish on create' do
          expect(Reactor::Event).not_to receive(:publish).with(:publish_on_create_if_enqueue_function, anything)

          Publisher.create!(should_run: false)
        end

        it 'does not publish on update' do
          instance = Publisher.create!(should_run: true)

          expect(Reactor::Event).not_to receive(:publish).with(:publish_on_create_if_enqueue_function, anything)

          instance.update!(should_run: false)
        end
      end
    end

    describe 'publish_on_update' do
      it 'publishes on create if watch attribute is present' do
        expect(Reactor::Event).to receive(:publish).with(:publish_on_update, anything).once

        Publisher.create!(watched_column: 'VALUE')
      end

      it 'does not publishes on create if watch attribute is nil' do
        expect(Reactor::Event).not_to receive(:publish).with(:publish_on_update, anything)

        Publisher.create!(watched_column: nil)
      end

      it 'does not publish unless changed' do
        instance = Publisher.create!(watched_column: 'VALUE')

        expect(Reactor::Event).not_to receive(:publish).with(:publish_on_update, anything)

        instance.update!(updated_at: Time.current)
      end

      it 'publishes on change' do
        instance = Publisher.create!(watched_column: 'VALUE')

        expect(Reactor::Event).to receive(:publish).with(:publish_on_update, anything).once

        instance.update!(watched_column: 'NEW_VALUE')
      end

      it 'publishes on change to nil' do
        instance = Publisher.create!(watched_column: 'VALUE')

        expect(Reactor::Event).to receive(:publish).with(:publish_on_update, anything).once

        instance.update!(watched_column: nil)
      end
    end

    describe 'publish_on_update_with_at_lambda' do
      it 'publishes on create' do
        expect(Reactor::Event).to receive(:publish).with(:publish_on_update_with_at_lambda, anything).once

        Publisher.create!(run_at: Time.current, watched_column: 'VALUE')
      end

      it 'publishes on update' do
        instance = Publisher.create!(run_at: Time.current)

        expect(Reactor::Event).to receive(:publish).with(:publish_on_update_with_at_lambda, anything).once

        instance.update!(watched_column: 'NEW_VALUE')
      end

      it 'does not publish the event when at is nil' do
        skip('TODO: Do not publish at: nil')
        instance = Publisher.create!(run_at: nil)

        expect(Reactor::Event).not_to receive(:publish).with(:publish_on_update_with_at_lambda, anything)

        instance.update!(watched_column: 'NEW_VALUE')
      end
    end

    describe 'publish_on_update_with_at_function' do
      it 'publishes on create' do
        expect(Reactor::Event).to receive(:publish).with(:publish_on_update_with_at_function, anything).once

        Publisher.create!(run_at: Time.current, watched_column: 'VALUE')
      end

      it 'publishes on update' do
        instance = Publisher.create!(run_at: Time.current)

        expect(Reactor::Event).to receive(:publish).with(:publish_on_update_with_at_function, anything).once

        instance.update!(watched_column: 'NEW_VALUE')
      end

      it 'does not publish the event when at is nil' do
        skip('TODO: Do not publish at: nil')
        instance = Publisher.create!(run_at: nil)

        expect(Reactor::Event).not_to receive(:publish).with(:publish_on_update_with_at_lambda, anything)

        instance.update!(watched_column: 'NEW_VALUE')
      end
    end

    describe 'publish_on_update_if_lambda' do
      it 'publishes on create' do
        expect(Reactor::Event).to receive(:publish).with(:publish_on_update_if_lambda, anything).once

        Publisher.create!(watched_column: 'VALUE')
      end

      it 'publishes on update' do
        instance = Publisher.create!

        expect(Reactor::Event).to receive(:publish).with(:publish_on_update_if_lambda, anything).once

        instance.update!(watched_column: 'NEW_VALUE')
      end
    end

    describe 'publish_on_update_if_function' do
      it 'publishes on create' do
        expect(Reactor::Event).to receive(:publish).with(:publish_on_update_if_function, anything).once

        Publisher.create!(watched_column: 'VALUE')
      end

      it 'publishes on update' do
        instance = Publisher.create!

        expect(Reactor::Event).to receive(:publish).with(:publish_on_update_if_function, anything).once

        instance.update!(watched_column: 'NEW_VALUE')
      end
    end

    describe 'publish_on_update_if_enqueue_lambda' do
      context 'when enqueue_if is true' do
        it 'publishes on create' do
          expect(Reactor::Event).to receive(:publish).with(:publish_on_update_if_enqueue_lambda, anything).once

          Publisher.create!(should_run: true, watched_column: 'VALUE')
        end

        it 'publishes on update' do
          instance = Publisher.create!(should_run: true)

          expect(Reactor::Event).to receive(:publish).with(:publish_on_update_if_enqueue_lambda, anything).once

          instance.update!(watched_column: 'NEW_VALUE')
        end
      end

      context 'when enqueue_if is false' do
        it 'does not publish on create' do
          expect(Reactor::Event).not_to receive(:publish).with(:publish_on_update_if_enqueue_lambda, anything)

          Publisher.create!(should_run: false, watched_column: 'VALUE')
        end

        it 'does not publish on update' do
          instance = Publisher.create!(should_run: true)

          expect(Reactor::Event).not_to receive(:publish).with(:publish_on_update_if_enqueue_lambda, anything)

          instance.update!(should_run: false, watched_column: 'NEW_VALUE')
        end
      end
    end

    describe 'publish_on_update_if_enqueue_function' do
      context 'when enqueue_if is true' do
        it 'publishes on create' do
          expect(Reactor::Event).to receive(:publish).with(:publish_on_update_if_enqueue_function, anything).once

          Publisher.create!(should_run: true, watched_column: 'VALUE')
        end

        it 'publishes on update' do
          instance = Publisher.create!(should_run: true)

          expect(Reactor::Event).to receive(:publish).with(:publish_on_update_if_enqueue_function, anything).once

          instance.update!(watched_column: 'NEW_VALUE')
        end
      end

      context 'when enqueue_if is false' do
        it 'does not publish on create' do
          expect(Reactor::Event).not_to receive(:publish).with(:publish_on_update_if_enqueue_function, anything)

          Publisher.create!(should_run: false, watched_column: 'VALUE')
        end

        it 'does not publish on update' do
          instance = Publisher.create!(should_run: true)

          expect(Reactor::Event).not_to receive(:publish).with(:publish_on_update_if_enqueue_function, anything)

          instance.update!(should_run: false, watched_column: 'NEW_VALUE')
        end
      end
    end
  end
end
