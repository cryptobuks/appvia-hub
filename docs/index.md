# What is the Hub

Developers can do incredible things. If you think about how important they are for enabling their company to operate, deliver, grow and "wow" customers, they're pretty valuable. But their abilities - just like other departments - are affected by the tools and support they're provided with.

In some cases the tools provided to Developers abstract them away from how the application has been deployed and managed i.e. a traditional PaaS which will test,  build and deploy the application on behalf of a developer. Making it difficult to troubleshoot issues or understand how something has happened when it isn't the expected outcome.

The hub sits somewhere in the middle! We want to enable developers as much as possible to focus on the important things, but we want them to be in control and have autonomy on how they are deploying the application and what resources they may need.

## What is the difference between this and a PaaS?

We don't see the hub as being a PaaS platform in the traditional sense, but more an orchestrator and aggregator of useful information. We don't want to abstract developers from being close to their application in terms of CI, deployments and operational implementation details i.e. good logging, monitoring, tracing etc. We want people to use what makes sense for their application with some healthy best practice defaults.

What we want to achieve is being able to provision resources quickly, simply and with minimal configuration that gets a developer going; but also, to provide useful information around the applications being managed i.e. what recent builds failed, what is deployed in what environment, the relationships between resources.

## What are these resources?

We have noticed that a lot of teams require additional resources or as the industry has coined 'DevOps Resources' to facilitate a developers needs. This tends to involve some onboarding of people into the github organisation, creating access to docker repositories, provisioning CI robot accounts, creating a kubernetes cluster, namespaces for the project, RBAC controls etc. 

As projects grow or as organisations grow, the demand for the above resources increases and eventually ends up a mix of manual and automated workloads. Visibility becomes poor and the resource provisioning becomes slow and results in developers being blocked, mistakes being made and time being consumed. 

We have split resources into themes:
- Code Management
- Docker Repositories
- Deployment Management

These themes are then split into provider type resources we are primarily focused on are:
- Code Repositories (github provider)
- Docker Repositories (quay provider)
- Kubernetes namespaces (deployment spaces) (kubernetes provider)
