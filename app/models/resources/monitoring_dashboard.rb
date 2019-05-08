module Resources
  class MonitoringDashboard < Resource
    attr_json :url, :string

    # Can only ever be "attached" to another resource
    validates :parent_id, presence: true
  end
end
