module JsonSchemaHelpers
  # Processes a flat Hash of values, converting fields that are meant to be
  # a Boolean, based on the provided JsonSchema spec
  def self.ensure_booleans(data, spec)
    return data if data.blank?

    spec.properties.each do |(name, property_spec)|
      data[name] = ActiveRecord::Type::Boolean.new.cast(data[name]) if property_spec.type.include?('boolean')
    end

    data
  end
end
