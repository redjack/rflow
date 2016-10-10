class CreateShards < ActiveRecord::Migration
  def self.up
    create_table(:shards, :id => false) do |t|
      t.string :uuid, :limit => 36, :primary => true
      t.string :name
      t.integer :count

      # STI
      t.string :type

      t.timestamps null: false
    end

    add_index :shards, :uuid, :unique => true
    add_index :shards, :name, :unique => true
  end

  def self.down
    drop_table :shards
  end
end
