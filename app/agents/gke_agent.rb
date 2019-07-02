require 'English'
require 'erb'
require 'google/apis/compute_v1'
require 'google/apis/container_v1beta1'
require 'googleauth'
require 'k8s-client'
require 'openssl'
require 'stringio'
require 'tempfile'
require 'yaml'

module GKE
  module Polices
    DEFAULT_PSP_CLUSTER_ROLE = <<~YAML.freeze
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      metadata:
        name: default:psp
      rules:
      - apiGroups:
        - policy
        resourceNames:
        - gce.unprivileged-addon
        resources:
        - podsecuritypolicies
        verbs:
        - use
    YAML

    DEFAULT_PSP_CLUSTERROLE_BINDING = <<~YAML.freeze
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRoleBinding
      metadata:
        name: default:psp
      roleRef:
        apiGroup: rbac.authorization.k8s.io
        kind: ClusterRole
        name: default:psp
      subjects:
      - apiGroup: rbac.authorization.k8s.io
        kind: Group
        name: system:authenticated
      - apiGroup: rbac.authorization.k8s.io
        kind: Group
        name: system:serviceaccounts
    YAML

    DEFAULT_CLUSTER_ADMIN_ROLE = <<~YAML.freeze
      apiVersion: v1
      kind: ServiceAccount
      metadata:
        name: sysadmin
        namespace: kube-system
    YAML

    DEFAULT_CLUSTER_ADMIN_BINDING = <<~YAML.freeze
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRoleBinding
      metadata:
        name: cluster:admin
      roleRef:
        apiGroup: rbac.authorization.k8s.io
        kind: ClusterRole
        name: cluster-admin
      subjects:
      - kind: ServiceAccount
        name: sysadmin
        namespace: kube-system
    YAML

    DEFAULT_BOOTSTRAP_JOB = <<-YAML.freeze
      apiVersion: batch/v1
      kind: Job
      metadata:
        name: hub-bootstrap
        namespace: kube-system
      spec:
        backoffLimit: 4
        template:
          spec:
            serviceAccountName: sysadmin
            restartPolicy: OnFailure
            containers:
            - name: bootstrap
              image: quay.io/appvia/hub-bootstrap:latest
              imagePullPolicy: Always
              env:
              - name: CONFIG_DIR
                value: /config
              volumeMounts:
              - name: bundle
                mountPath: /config/bundles
            volumes:
            - name: bundle
              configMap:
                name: hub-bootstrap-bundle
    YAML
  end
end

module GKE
  module Helper
    Container = Google::Apis::ContainerV1beta1
    Compute = Google::Apis::ComputeV1

    # service_account_credentials returns the credentials for a service account
    def service_account_credentials(endpoint, name)
      client = kube_client(endpoint)
      sa = client.api('v1').resource('serviceaccounts', namespace: 'kube-system').get(name)
      secret = client.api('v1').resource('secrets', namespace: 'kube-system').get(sa.secrets.first.name)
      secret.data.token
    end

    def default_nat(name = 'cloud-nat')
      [
        Google::Apis::ComputeV1::RouterNat.new(
          log_config: Google::Apis::ComputeV1::RouterNatLogConfig.new(enable: false, filter: 'ALL'),
          name: name,
          nat_ip_allocate_option: 'AUTO_ONLY',
          source_subnetwork_ip_ranges_to_nat: 'ALL_SUBNETWORKS_ALL_IP_RANGES'
        )
      ]
    end

    # hold_for_operation is responisble for waiting for an operation to complete or error
    # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    def hold_for_operation(id, interval = 10, max_retries = 3, max_timeout = 15 * 60)
      max_attempts = max_timeout / interval
      retries = attempts = 0

      # @TODO this feels like a very naive timeout, but i don't know ruby too well so :-)
      while retries < max_retries
        begin
          resp = get_operation_status(id)
          if !resp.nil? && (resp.status == 'DONE')
            if !resp.status_message.nil? && !resp.status_message.empty?
              raise Exception, "operation: #{x.operation_type} has failed with error message: #{resp.status_message}"
            end

            break
          end
          # @step: throw an exception if we've overrun the max attempts
          raise Exception, "operation: #{x.operation_type}, target: #{x.target_link} has timed out" if attempts > max_attempts

          sleep(interval)
          attempts += 1
        rescue StandardError
          retries += 1
          sleep(5)
        end
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity

    # get_operation_status returns the current status of an operation
    def get_operation_status(id, project = @project, region = @region)
      gke.get_project_location_operation("projects/#{project}/locations/#{region}/operations/*", operation_id: id)
    end

    # list_clusters returns a list of clusters
    def list_clusters(project = @project, region = @region)
      gke.list_zone_clusters(nil, nil, parent: "projects/#{project}/locations/#{region}").clusters || []
    end

    # list_locations returns a list of compute locations
    def list_locations(region = @region, project = @project)
      gke.list_project_locations("projects/#{project}").locations.select do |x|
        x.name.start_with?("#{region}-")
      end.map(&:name)
    end

    # authorize is responsible for providing an access token to operate
    def authorize
      unless defined?(@credentials)
        @authorizer ||= Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: StringIO.new(@account),
          scope: 'https://www.googleapis.com/auth/cloud-platform'
        )
        @credentials = @authorizer.fetch_access_token!
      end
      @authorizer
    end

    # router returns a specfic router
    def router(name, project = @project, region = @region)
      routers(project, region).select { |x| x.name == name }.first
    end

    # router? check if the router exists
    def router?(name, project = @project, region = @region)
      routers(project, region).map(&:name).include?(name)
    end

    # routers returns the list of routers
    def routers(project = @project, region = @region)
      compute.list_routers(project, region).items
    end

    # network? checks if the network exists in the region and project
    def network?(name, project = @project, region = @region)
      networks(project, region).items.map(&:name).include?(name)
    end

    # networks returns a list of networks in the region and project
    def networks(project = @project, _region = @region)
      compute.list_networks(project)
    end

    # subnet? checks if the subnet exists in the project, network and region
    def subnet?(name, network, _project = @project, _region = @region)
      subnets(network).include?(name)
    end

    # subnets returns a list of subnets in the network
    def subnets(network, region = @region, project = @project)
      compute.list_subnetworks(project, region).items.select do |x|
        x.network.end_with?(network)
      end.map(&:name)
    end

    # exist? check if a gke cluster exists
    def exist?(name, project = @project, region = @region)
      list_clusters(project, region).map(&:name).include?(name)
    end

    # compute returns a gcp complete client for the region
    def compute
      unless defined?(@compute)
        @compute = Compute::ComputeService.new
        @compute.authorization = authorize
      end
      @compute
    end

    # client returns the container client for us
    def gke
      unless defined?(@gke)
        @gke = Container::ContainerService.new
        @gke.authorization = authorize
      end
      @gke
    end
  end
end

module GKE
  module Template
    class Render
      attr_accessor :context

      def initialize(context)
        @context = context
      end

      def render(template)
        ERB.new(template).result(get_binding)
      end

      # rubocop:disable Naming/AccessorMethodName
      def get_binding
        binding
      end
      # rubocop:enable Naming/AccessorMethodName
    end
  end
end

## rubocop:disable Metrics/MethodLength,Metrics/ClassLength
class GKEAgent
  include GKE::Polices
  include GKE::Helper
  include GKE::Template

  def initialize(account, project, region)
    @account = account
    @project = project
    @region  = region
  end

  # default_options are the default options for a cluster
  def default_options
    {
      authorized_master_cidrs: [{ name: 'any', cidr: '0.0.0.0/0' }],
      cluster_ipv4_cidr: '',
      create_subnetwork: false,
      disk_size_gb: 100,
      enable_autorepair: true,
      enable_autoscaler: true,
      enable_autoupgrade: true,
      enable_binary_authorization: false,
      enable_horizontal_pod_autoscaler: false,
      enable_http_loadbalancer: true,
      enable_istio: false,
      enable_logging: true,
      enable_monitoring: true,
      enable_network_polices: true,
      enable_pod_security_polices: true,
      enable_private_endpoint: false,
      enable_private_network: true,
      image_type: 'COS',
      machine_type: 'n1-standard-1',
      maintenance_window: '03:00',
      master_ipv4_cidr_block: '172.16.0.0/28',
      max_nodes: 10,
      network: 'default',
      preemptible: false,
      region: 'europe-west2',
      services_ipv4_cidr: '',
      size: 1,
      subnetwork: 'default',
      version: 'latest'
    }.freeze
  end
  # rubocop:enable Metrics/MethodLength

  # provision is responsible for provisioning the cluster
  # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
  def provision(options = {})
    # @step: validate the options
    raise ArgumentError, 'you must specify a cluster name' unless options[:name]
    raise ArgumentError, 'you must specify a cluster description' unless options[:description]

    name = options[:name]

    # @step: merge the default options with user defined ones
    config = default_options.merge(options)

    # @step: we check if the cluster already exists
    unless exist?(name)
      # @step: attempt to provision the cluster
      path = "projects/#{@project}/locations/#{@region}"
      operation = gke.create_project_location_cluster(path, cluster_spec(config))
      hold_for_operation(operation.name)
    end

    # @step: if private network we need to create a cloud-nat devices if
    # not already there
    edge = router('router')
    if edge.nats.nil?
      edge.nats = default_nat('cloud-nat')
      compute.patch_router(@project, @region, 'router', edge)
    end

    # @step: wait on the api to become available
    hold_for_kubeapi(name)

    # @step: get the cluster endpoint
    cluster = list_clusters.select { |x| x.name = name }.first

    # @step: if private networking we need to provision a cloud-nat
    if config[:enable_pod_security_polices]
      kubectl(cluster.endpoint, DEFAULT_PSP_CLUSTER_ROLE)
      kubectl(cluster.endpoint, DEFAULT_PSP_CLUSTERROLE_BINDING)
    end

    # @step: apply the default cluster admin
    kubectl(cluster.endpoint, DEFAULT_CLUSTER_ADMIN_ROLE)
    kubectl(cluster.endpoint, DEFAULT_CLUSTER_ADMIN_BINDING)

    # @step: provision the software bundles
    kubectl(cluster.endpoint, bundle_options(config))
    kubectl(cluster.endpoint, DEFAULT_BOOTSTRAP_JOB)

    # @step: wait for the bootstrapper to complete
    puts <<~TEXT
      Kubernetes API: https://#{cluster.endpoint}
      GCP Region: #{@region}
      GCP Project: #{@project}
      Certificate Autority: #{cluster.master_auth.cluster_ca_certificate}
      Cluster Token: #{service_account_credentials(cluster.endpoint, 'sysadmin')}
      Cloud NAT: #{config[:enable_private_network]}
    TEXT
  end
  # rubocop:enable Metrics/AbcSize

  # destroy is responsible for deleting a gke cluster
  def destroy(name, project = @project, region = @region)
    # @step: check the cluster exists
    raise Exception, "the cluster: #{name} does not exist" unless exist?(name)

    gke.delete_project_location_cluster("projects/#{project}/locations/#{region}/clusters/#{name}")
  end

  private

  # hold_for_kubeapi is responsible for waiting the api is available
  def hold_for_kubeapi(name, project = @project, region = @region)
    # @step: check the cluster exists
    raise ArgumentError, 'cluster does not exist' unless exist?(name, project, region)

    # @step: grab the cluster
    cluster = list_clusters(project, region).select { |x| x.name = name }.first

    client  = kube_client(cluster.endpoint)
    max_attempts = 60
    attempts = 0

    # @step: wait for the api to be available
    loop do
      break if client.api('v1').resource('nodes').list
    rescue StandardError
      attempts += 1
      sleep(5)
      raise Exception, 'timed out waiting for the api' if attempts >= max_attempts
    end
  end

  # bundle_options returns the helm values for grafana
  def bundle_options(options)
    template = <<~YAML
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: hub-bootstrap-bundle
        namespace: kube-system
      data:
        charts: |
          loki/loki-stack,loki,-f /config/bundles/grafana.yaml
          stable/prometheus,kube-system,
        repositories: |
          loki,https://grafana.github.io/loki/charts
        grafana.yaml: |
          loki:
            enabled: true
          promtail:
            enabled: true
          grafana:
            enabled: false
            sidecar:
              datasources:
                enabled: true
            <% if context[:grafana_ingress] %>
            service:
              type: NodePort
              port: 80
              targetPort: 3000
              annotations: {}
              labels: {}

            ingress:
              enabled: true
              path: /
              hosts:
                - <%= context[:grafana_hostname] %>
            <% end %>
            grafana.ini:
              paths:
                data: /var/lib/grafana/data
                logs: /var/log/grafana
                plugins: /var/lib/grafana/plugins
                provisioning: /etc/grafana/provisioning
              analytics:
                check_for_updates: true
              log:
                mode: console
              grafana_net:
                url: https://grafana.net
              <% if context[:github_client_id] %>
              auth.github:
                client_id: <%= context[:github_client_id] %>
                client_secret: <%= config[:github_client_secret] %>
                enabled: true
                allow_sign_up: true
                scopes: user,read:org
                auth_url: https://github.com/login/oauth/authorize
                token_url: https://github.com/login/oauth/access_token
                api_url: https://api.github.com/user
                allowed_organizations: %<= context[:github_organization] %>
              <% end %>
          prometheus:
            enabled: false
            server:
              fullnameOverride: prometheus-server
    YAML
    Render.new(options).render(template)
  end

  # kube_client returns a kubernetes client
  def kube_client(endpoint)
    @kube_client ||= K8s.client(
      ("https://#{endpoint}" unless endpoint.start_with?('https')),
      auth_token: authorize.access_token,
      ssl_verify_peer: false
    )
  end

  # kubectl is responsible for performing an action with kubectl
  # rubocop:disable Metrics/CyclomaticComplexity
  def kubectl(endpoint, manifest)
    resource = K8s::Resource.from_json(YAML.safe_load(manifest).to_json)
    raise ArgumentError, 'no api version associated to resource' unless resource.apiVersion
    raise ArgumentError, 'no kind associated to resource' unless resource.kind
    raise ArgumentError, 'no metadata associated to resource' unless resource.metadata
    raise ArgumentError, 'no name associated to resource' unless resource.metadata.name

    name = resource.metadata.name
    kind = resource.kind.downcase
    version = resource.apiVersion

    # @step create the kubernetes client
    endpoint = "https://#{endpoint}" unless endpoint.start_with?('https')
    client   = kube_client(endpoint)

    # @step: check if the resource exists
    begin
      client.api(version).resource("#{kind}s", namespace: resource.metadata.namespace).get(name)
    rescue K8s::Error::NotFound
      client.api(version).resource("#{kind}s", namespace: resource.metadata.namespace).create_resource(resource)
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  # cluster_spec is responsible for generating a cluster specification from options
  # rubocop:disable Metrics/AbcSize
  def cluster_spec(options)
    locations = list_locations

    request = Google::Apis::ContainerV1beta1::CreateClusterRequest.new(
      parent: "projects/#{@project}/locations/#{@region}",
      project_id: @project
    )
    request.cluster = Google::Apis::ContainerV1beta1::Cluster.new(
      name: options[:name],
      description: options[:description],
      initial_cluster_version: options[:version],

      #
      ## Addons
      #
      addons_config: Google::Apis::ContainerV1beta1::AddonsConfig.new(
        cloud_run_config: Google::Apis::ContainerV1beta1::CloudRunConfig.new(
          disabled: !options[:enable_cloud_run]
        ),
        horizontal_pod_autoscaling: Google::Apis::ContainerV1beta1::HorizontalPodAutoscaling.new(
          disabled: !options[:enable_horizontal_pod_autoscaler]
        ),
        http_load_balancing: Google::Apis::ContainerV1beta1::HttpLoadBalancing.new(
          disabled: !options[:enable_http_loadbalancer]
        ),
        istio_config: Google::Apis::ContainerV1beta1::IstioConfig.new(
          auth: 'AUTH_MUTUAL_TLS',
          disabled: !options[:enable_istio]
        ),
        kubernetes_dashboard: Google::Apis::ContainerV1beta1::KubernetesDashboard.new(
          disabled: true
        ),
        network_policy_config: Google::Apis::ContainerV1beta1::NetworkPolicyConfig.new(
          disabled: false
        )
      ),

      maintenance_policy: Google::Apis::ContainerV1beta1::MaintenancePolicy.new(
        window: Google::Apis::ContainerV1beta1::MaintenanceWindow.new(
          daily_maintenance_window: Google::Apis::ContainerV1beta1::DailyMaintenanceWindow.new(
            start_time: options[:maintenance_window]
          )
        )
      ),

      #
      ## Authentication
      #
      master_auth: Google::Apis::ContainerV1beta1::MasterAuth.new(
        client_certificate_config: Google::Apis::ContainerV1beta1::ClientCertificateConfig.new(
          issue_client_certificate: false
        )
      ),

      #
      ## Network
      #
      ip_allocation_policy: Google::Apis::ContainerV1beta1::IpAllocationPolicy.new(
        cluster_ipv4_cidr_block: options[:cluster_ipv4_cidr],
        create_subnetwork: options[:create_subnetwork],
        services_ipv4_cidr_block: options[:services_ipv4_cidr],
        subnetwork_name: options[:subnetwork],
        use_ip_aliases: true
      ),
      locations: locations,

      #
      ## Features
      #
      monitoring_service: ('monitoring.googleapis.com/kubernetes' if options[:enable_monitoring]),
      logging_service: ('logging.googleapis.com/kubernetes' if options[:enable_logging]),

      binary_authorization: Google::Apis::ContainerV1beta1::BinaryAuthorization.new(
        enabled: options[:enable_binary_authorization]
      ),
      legacy_abac: Google::Apis::ContainerV1beta1::LegacyAbac.new(
        enabled: false
      ),
      network_policy: Google::Apis::ContainerV1beta1::NetworkPolicy.new(
        enabled: options[:enable_network_polices]
      ),
      pod_security_policy_config: Google::Apis::ContainerV1beta1::PodSecurityPolicyConfig.new(
        enabled: options[:enable_pod_security_polices]
      ),

      #
      ## Node Pools
      #
      node_pools: [
        Google::Apis::ContainerV1beta1::NodePool.new(
          autoscaling: Google::Apis::ContainerV1beta1::NodePoolAutoscaling.new(
            autoprovisioned: false,
            enabled: options[:enable_autoscaler],
            max_node_count: options[:max_nodes],
            min_node_count: options[:size]
          ),
          config: Google::Apis::ContainerV1beta1::NodeConfig.new(
            disk_size_gb: options[:disk_size_gb],
            image_type: options[:image_type],
            machine_type: options[:machine_type],
            oauth_scopes: [
              'https://www.googleapis.com/auth/compute',
              'https://www.googleapis.com/auth/devstorage.read_only',
              'https://www.googleapis.com/auth/logging.write',
              'https://www.googleapis.com/auth/monitoring'
            ],
            preemptible: options[:preemptible]
          ),
          initial_node_count: options[:size],
          locations: locations,
          management: Google::Apis::ContainerV1beta1::NodeManagement.new(
            auto_repair: options[:enable_autorepair],
            auto_upgrade: options[:enable_autoupgrade]
          ),
          max_pods_constraint: Google::Apis::ContainerV1beta1::MaxPodsConstraint.new(
            max_pods_per_node: 110
          ),
          name: 'compute',
          version: options[:version]
        )
      ]
    )

    if options[:enable_private_network]
      request.cluster.private_cluster = true
      request.cluster.private_cluster_config = Google::Apis::ContainerV1beta1::PrivateClusterConfig.new(
        enable_private_endpoint: options[:enable_private_endpoint],
        enable_private_nodes: true,
        master_ipv4_cidr_block: options[:master_ipv4_cidr_block]
      )

      # @step: do we have any authorized cidr's
      if options[:authorized_master_cidrs].size.positive?
        request.cluster.master_authorized_networks_config = Google::Apis::ContainerV1beta1::MasterAuthorizedNetworksConfig.new(
          cidr_blocks: [],
          enabled: true
        )
        options[:authorized_master_cidrs].each do |x|
          block = Google::Apis::ContainerV1beta1::CidrBlock.new(
            cidr_block: x[:cidr],
            display_name: x[:name]
          )

          request.cluster.master_authorized_networks_config.cidr_blocks.push(block)
        end
      end
    end
    request
  end
  # rubocop:enable Metrics/AbcSize
end
# rubocop:enable Metrics/MethodLength,Metrics/ClassLength

require 'pp'

account = File.read('../../account.json')
region = 'europe-west2'
project = 'gke-learning-242311'

c = GKEAgent.new(account, project, region)
c.provision(
  name: 'test',
  description: 'just a test',
  version: '1.13.7-gke.8'
)
