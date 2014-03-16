class CreateComponents < ActiveRecord::Migration
  def self.up
    create_table(:components, :id => false) do |t|
      t.string :uuid, :limit => 36, :primary => true
      t.string :name
      t.boolean :managed, :default => true
      t.text   :specification
      t.text   :options

      # UUID version of belongs_to :shard
      t.string :shard_uuid

      t.timestamps
    end

    add_index :components, :uuid, :unique => true
    add_index :components, :name, :unique => true
    add_index :components, :shard_uuid
  end

  def self.down
    drop_table :components
  end
end
