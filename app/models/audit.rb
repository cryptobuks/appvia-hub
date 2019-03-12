class Audit < Audited::Audit
  before_create :set_descriptors_if_needed
  before_create :set_auditable_model_name

  after_create { readonly! }
  after_find { readonly! }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }

  private

  def set_descriptors_if_needed
    if auditable.present? &&
       auditable.respond_to?(:descriptor)
      self.auditable_descriptor = auditable.descriptor
    end

    if associated.present? &&
       associated.respond_to?(:descriptor)
      self.associated_descriptor = associated.descriptor
    end

    self.user_email = user.email if user
  end

  def set_auditable_model_name
    self.auditable_model_name = auditable.model_name.name if auditable.present?
  end
end
