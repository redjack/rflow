class CreateConnections < ActiveRecord::Migration
  def self.up
    create_table :connections do |t|
      t.string :uuid
      t.string :name

      # Data flows from an output port to an input port
      t.string :output_port_uuid
      t.string :input_port_uuid
 
      t.timestamps
    end

    add_index :connections, :uuid, :unique => true
    add_index :connections, [:output_port_uuid, :input_port_uuid], :unique => true
    # An output port can only connect to a single input port
    add_index :connections, :output_port_uuid, :unique => true
  end
 
  def self.down
    drop_table :connections
  end
end
