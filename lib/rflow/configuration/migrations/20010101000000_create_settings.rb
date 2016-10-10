class CreateSettings < ActiveRecord::Migration
  def self.up
    create_table(:settings, :id => false) do |t|
      t.string :name, :primary => true
      t.text   :value

      t.timestamps null: false
    end
  end

  def self.down
    drop_table :settings
  end
end
