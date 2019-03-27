require 'rails_helper'

RSpec.describe ResourceProvisioningService, type: :service do
  let(:integration) { create_mocked_integration }

  let! :resource do
    create :code_repo, integration: integration
  end

  describe '#request_create' do
    it 'schedules a Resources::RequestCreateWorker' do
      expect do
        subject.request_create resource
      end.to change(Resources::RequestCreateWorker.jobs, :size).by(1)

      last_job = Resources::RequestCreateWorker.jobs.last
      expect(last_job['args']).to eq [resource.id]
    end

    it 'logs an audit' do
      expect do
        subject.request_create resource
      end.to change(Audit, :count).by(1)

      audit = resource.audits.last
      expect(audit.action).to eq 'request_create'
      expect(audit.associated).to eq resource.project
    end
  end

  describe '#request_delete' do
    it 'schedules a Resources::RequestDeleteWorker' do
      expect do
        subject.request_delete resource
      end.to change(Resources::RequestDeleteWorker.jobs, :size).by(1)

      last_job = Resources::RequestDeleteWorker.jobs.last
      expect(last_job['args']).to eq [resource.id]
    end

    it 'logs an audit' do
      expect do
        subject.request_delete resource
      end.to change(Audit, :count).by(2)

      expect(resource.deleting?).to be true

      audit = resource.audits.last
      expect(audit.action).to eq 'request_delete'
      expect(audit.associated).to eq resource.project
    end
  end
end
