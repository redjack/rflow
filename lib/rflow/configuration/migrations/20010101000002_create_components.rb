class CreateComponents < ActiveRecord::Migration
  def self.up
    create_table :components do |t|
      t.string :uuid
      t.string :name
      t.boolean :managed, :default => true
      t.text   :specification
      t.text   :options
      
      t.timestamps
    end

    add_index :components, :name, :unique => true
    add_index :components, :uuid, :unique => true
  end
 
  def self.down
    drop_table :components
  end
end
