# Architecture

We have split resources into Capabilities

- Code Management
- Docker Repositories
- Deployment Management

These Capabilities are then split into provider type resources, the current providers are:

- Code Repositories (github provider)
- Docker Repositories (quay provider)
- Kubernetes namespaces (deployment spaces) (kubernetes provider)

Agents are affiliated with these providers i.e. there is an agent to provider relationship that is coupled and the agents are usually decoupled from the main hub itself i.e. a separate codebase. This is to enable the agents to move more closely with the provider technology without necessarily having to change the hub i.e. the functionality of the agent that talks to the kubernetes API, (therefore offering a Kubernetes provider to the hub), may not change functionality in relation to the hub but may need to move with the kubernetes API versions and so can iterate independently.

As a provider may offer the same functionality multiple times, we deem this as an integration of that provider i.e. you may use the Github provider, but have 2 organisations in Github and will want to have resources created in either of these. This means you would only have 1 provider, but 2 integrations to that provider.

As hinted at above, the hub is the user interface and core orchestrator between all the providers and manages the integration configuration for these. The configuration is done by an administrator within the hub, and provides configuration to talk to the agents and also configuration for the upstream provider it is communicating with.

```
[Hub] <-> [Agent] <-> [Provider]
```

The hub will make sure that all resource requests made by a user are acted upon and will provide a status update on its progression to the user.

## Supported Integration Agents

We currently have a few agents for the below providers.

- [Github, which is part of the hub code base](https://github.com/appvia/appvia-hub/)
- [Quay, for provisioning Docker Repositories in Quay](https://github.com/appvia/hub-quay-agent)
- [Kubernetes, for managing Namespaces](https://github.com/appvia/hub-kubernetes-agent)



## Provider Configuration

Provider configuration is managed [within the hub provider configuration](https://github.com/appvia/appvia-hub/blob/master/config/providers.yml) and defines the configuration schema to be able to configure the multiple agents for upstream integrations. It might be that there will be one provider i.e. Github, however, you may have two integrations, one for an on-premise Github Enterprise installation as well as one for Github SaaS.
