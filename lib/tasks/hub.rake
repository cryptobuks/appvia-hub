namespace :hub do
  namespace :danger_zone do
    desc 'WARNING: will delete all resources and spaces, '\
         'together with their audit entries. Note: will still delete resources '\
         'in the db even if agent(s) throw an error for request deletes.'
    task clean_hub: :environment do
      require 'sidekiq/testing'
      Sidekiq::Testing.inline! do
        HubCleaner.delete_resources
        HubCleaner.delete_projects
      end
    end
  end
end

module HubCleaner
  class << self
    def delete_resources
      provisioning_service = ResourceProvisioningService.new
      Resource.all.each do |r|
        provisioning_service.request_delete r
      rescue ActiveRecord::StaleObjectError
        # Handle optimistic locking error
        r.reload.destroy
      end
      Resource.destroy_all
      delete_audits_for 'Resource'
    end

    def delete_projects
      Project.destroy_all
      delete_audits_for 'Project'
    end

    def delete_audits_for(auditable_type)
      Audit.where(auditable_type: auditable_type).each(&:delete)
    end
  end
end
