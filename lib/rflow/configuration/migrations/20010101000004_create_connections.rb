class CreateConnections < ActiveRecord::Migration
  def self.up
    create_table :connections do |t|
      t.string :uuid
      t.string :name

      # To allow for multiple types of connections
      t.string :type

      # Data flows from an output port to an input port
      t.string  :output_port_uuid
      t.string  :output_port_key, :default => '0'
      t.string  :input_port_uuid
      t.string  :input_port_key, :default => '0'

      t.text :options
      
      t.timestamps
    end

    add_index :connections, :uuid, :unique => true
    # An output port can only connect to a single input port/key
    add_index :connections, [:output_port_uuid, :output_port_key], :unique => true
  end
 
  def self.down
    drop_table :connections
  end
end
