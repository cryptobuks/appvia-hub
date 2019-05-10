module SettingsService
  class << self
    SLUG = 'settings'.freeze

    KEYS = %w[crisp_website_id].freeze

    def all
      hash_record.data
    end

    def get(name)
      raise ArgumentError, "'#{name}' is not a valid setting name" unless KEYS.include?(name)

      all[name]
    end

    def update_all!(hash)
      hash_record.update! data: hash.stringify_keys.slice(*KEYS)
      hash_record
    end

    private

    def hash_record
      HashRecord.find_or_create_by!(slug: SLUG)
    end
  end
end
