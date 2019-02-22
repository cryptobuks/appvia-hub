module Resources
  class CodeRepo < Resource
    attr_json :private, :boolean
    attr_json :full_name, :string
    attr_json :url, :string
  end
end
