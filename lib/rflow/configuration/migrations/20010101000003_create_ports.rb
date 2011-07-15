class CreatePorts < ActiveRecord::Migration
  def self.up
    create_table(:ports, :id => false) do |t|
      t.string :uuid, :limit => 36, :primary => true
      t.string :name

      # For STI
      t.text   :type

      # UUID version of belongs_to :component 
      t.string :component_uuid
      
      t.timestamps
    end

    add_index :ports, :uuid, :unique => true
    add_index :ports, :component_uuid
    add_index :ports, [:component_uuid, :name], :unique => true
  end
 
  def self.down
    drop_table :ports
  end
end
