# frozen_string_literal: true

require 'active_record'

ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: ':memory:'

ActiveRecord::Migration.create_table :auctions do |t|
  t.string :name
  t.datetime :start_at
  t.datetime :close_at
  t.boolean :we_want_it
  t.integer :pet_id

  t.timestamps null: false
end

ActiveRecord::Migration.create_table :publishers do |t|
  t.integer :pet_id

  t.boolean  :should_run
  t.string   :watched_column
  t.datetime :run_at

  t.timestamps null: false
end

ActiveRecord::Migration.create_table :pets do |t|
  t.integer :awesomeness
  t.string :type

  t.timestamps null: false
end

ActiveRecord::Migration.create_table :arbitrary_models do |t|
  t.integer :awesomeness

  t.timestamps null: false
end
