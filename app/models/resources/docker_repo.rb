module Resources
  class DockerRepo < Resource
    VISIBILITIES = %w[internal private public].freeze

    attr_json :visibility, :string
    attr_json :base_uri, :string

    validates :visibility,
      inclusion: { in: VISIBILITIES },
      allow_nil: true
  end
end
