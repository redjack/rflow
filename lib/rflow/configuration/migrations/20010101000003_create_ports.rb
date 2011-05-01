class CreatePorts < ActiveRecord::Migration
  def self.up
    create_table :ports do |t|
      t.string :uuid
      t.string :name
      
      # For STI
      t.text   :type

      # UUID version of belongs_to :component 
      t.string :component_uuid
      
      t.timestamps
    end
  end
 
  def self.down
    drop_table :ports
  end
end
