class CreateUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :users, id: :uuid do |t|
      t.string :email, null: false
      t.string :name
      t.datetime :last_seen_at

      t.timestamps

      t.index :email, unique: true
    end
  end
end
