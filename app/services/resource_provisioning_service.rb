class ResourceProvisioningService
  def request_create(resource)
    Resources::RequestCreateWorker.perform_async resource.id

    Audit.create!(
      action: 'request_create',
      auditable: resource,
      associated: resource.project
    )

    true
  end

  def request_delete(resource)
    resource.deleting!

    Resources::RequestDeleteWorker.perform_async resource.id

    Audit.create!(
      action: 'request_delete',
      auditable: resource,
      associated: resource.project
    )

    true
  end
end
