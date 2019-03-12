class AddAuditedModelNameToAudits < ActiveRecord::Migration[5.2]
  def change
    add_column :audits, :auditable_model_name, :string
  end
end
