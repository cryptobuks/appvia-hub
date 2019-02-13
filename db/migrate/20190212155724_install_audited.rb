class InstallAudited < ActiveRecord::Migration[5.2]
  def self.up
    create_table :audits, force: true do |t|
      t.belongs_to :auditable, polymorphic: true, type: :uuid
      t.string :auditable_descriptor
      t.belongs_to :associated, polymorphic: true, type: :uuid
      t.string :associated_descriptor
      t.belongs_to :user, polymorphic: true, type: :uuid
      t.string :username
      t.string :user_email
      t.string :action
      t.jsonb :audited_changes
      t.integer :version, default: 0
      t.string :comment
      t.string :remote_address
      t.string :request_uuid
      t.datetime :created_at, null: false
    end

    add_index :audits, :user_email
    add_index :audits, :request_uuid
    add_index :audits, :created_at
  end

  def self.down
    drop_table :audits
  end
end
