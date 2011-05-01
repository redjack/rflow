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
  end
 
  def self.down
    drop_table :connections
  end
end
