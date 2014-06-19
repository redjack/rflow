class CreateConnections < ActiveRecord::Migration
  def self.up
    create_table(:connections, :id => false) do |t|
      t.string :uuid, :limit => 36, :primary => false
      t.string :name

      # To allow for multiple types of connections
      t.string :type

      # round-robin
      t.string :delivery

      # Data flows from an output port to an input port
      t.string  :output_port_uuid
      t.string  :output_port_key, :default => '0'
      t.string  :input_port_uuid
      t.string  :input_port_key, :default => '0'

      t.text :options

      t.timestamps
    end

    add_index :connections, :uuid, :unique => true
  end

  def self.down
    drop_table :connections
  end
end
