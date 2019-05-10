namespace :hub do
  namespace :danger_zone do
    desc 'WARNING: will delete all resources and spaces, '\
         'together with their audit entries. Note (1): will still delete resources '\
         'in the db even if agent(s) throw an error for request deletes. '\
         'Note (2): you can exclude certain spaces by setting the `EXCLUDE_SPACES env var`, '\
         'e.g.: EXCLUDE_SPACES="foo-1,bar,another-space" bin/rails hub:danger_zone:clean_hub'
    task clean_hub: :environment do
      exclude_spaces = Array(
        (ENV['EXCLUDE_SPACES'] || '').split(',')
      ).map(&:strip)

      exclude_project_ids = if exclude_spaces.present?
                              Project.where(slug: exclude_spaces).pluck(:id)
                            else
                              []
                            end

      require 'sidekiq/testing'
      Sidekiq::Testing.inline! do
        HubCleaner.delete_resources exclude_project_ids
        HubCleaner.delete_projects exclude_project_ids
      end
    end
  end
end

module HubCleaner
  class << self
    def delete_resources(exclude_project_ids)
      provisioning_service = ResourceProvisioningService.new

      ids = []

      Resource.where.not(project_id: exclude_project_ids).each do |r|
        ids << r.id
        puts "Requesting deletion for resource '#{r.descriptor}' (ID: #{r.id})"
        provisioning_service.request_delete r
      rescue ActiveRecord::StaleObjectError
        # Handle optimistic locking error
        r.reload.destroy if Resource.exists? r.id
      end

      # Just in case they've hung around due to errors from the agent
      Resource.where.not(project_id: exclude_project_ids).destroy_all

      delete_audits_for 'Resource', ids
    end

    def delete_projects(exclude_project_ids)
      ids = []

      Project.where.not(id: exclude_project_ids).each do |p|
        ids << p.id
        puts "Requesting deletion for space '#{p.slug}' (ID: #{p.id})"
        p.destroy
      end

      delete_audits_for 'Project', ids
    end

    def delete_audits_for(auditable_type, auditable_ids)
      Audit.where(auditable_type: auditable_type, auditable_id: auditable_ids).each(&:delete)
    end
  end
end
