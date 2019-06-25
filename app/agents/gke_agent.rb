require 'google/apis/compute_v1'
require 'google/apis/container_v1beta1'
require 'googleauth'
require 'kubeclient'
require 'openssl'
require 'stringio'

class GKEAgent
  DefaultPspClusterRole = <<-EOF
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
EOF
  DefaultPspClusterRoleBinding = <<-EOF
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
EOF

  DefaultClusterAdminRole = <<-EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin
  namespace: kube-system
EOF
  DefaultClusterAdminBinding = <<EOF
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
  name: admin
  namespace: kube-system
EOF

  Container = Google::Apis::ContainerV1beta1
  Compute = Google::Apis::ComputeV1

  def initialize(account, project, region)
    @account = account
    @project = project
    @region  = region
  end

  # default_options are the default options for a cluster
  def default_options
    {
      authorized_master_cidrs: [{name: "any",cidr: "0.0.0.0/0"}],
      cluster_ipv4_cidr: "",
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
      image_type: "COS",
      machine_type: "n1-standard-1",
      maintenance_window: "03:00",
      master_ipv4_cidr_block: "172.16.0.0/28",
      max_nodes: 10,
      network: "default",
      preemptible: false,
      region: "europe-west2",
      services_ipv4_cidr: "",
      size: 1,
      subnetwork: "default",
      version: "latest",
    }
  end

  # provision is responsible for
  def provision(name, description, options = {})
    # @step: merge the default options with user defined ones
    o = default_options.merge(options)

    # @step: we check if the cluster already exists
    unless exist?(name)
      # @step: get a list of location within the region
      locations = list_locations(@region)
#      network = o[:network]
#      subnet = o[:subnetwork]

      # @step: we should probably with some sanity checks here
#      unless network.empty?
#        raise ArgumentError.new("network: #{network} does not exist") unless network?(network)
#      end
#      if not subnet.empty? and not [:create_subnetwork]
#        raise ArgumentError.new("subnetwork: #{subnet} does not exist") unless subnet?(subnet)
#      end

      request = Google::Apis::ContainerV1beta1::CreateClusterRequest.new({
        :parent     => "projects/#{@project}/locations/#{@region}",
        :project_id => @project,
      })
      cluster = Google::Apis::ContainerV1beta1::Cluster.new({
        :name                    => name,
        :description             => description,
        :initial_cluster_version => o[:version],

        #
        ## Addons
        #
        :addons_config  => Google::Apis::ContainerV1beta1::AddonsConfig.new({
          :cloud_run_config => Google::Apis::ContainerV1beta1::CloudRunConfig.new({
            :disabled => !o[:enable_cloud_run]
          }),
          :horizontal_pod_autoscaling => Google::Apis::ContainerV1beta1::HorizontalPodAutoscaling.new({
            :disabled => !o[:enable_horizontal_pod_autoscaler],
          }),
          :http_load_balancing => Google::Apis::ContainerV1beta1::HttpLoadBalancing.new({
            :disabled => !o[:enable_http_loadbalancer]
          }),
          :istio_config => Google::Apis::ContainerV1beta1::IstioConfig.new({
            :auth     => "AUTH_MUTUAL_TLS",
            :disabled => !o[:enable_istio],
          }),
          :kubernetes_dashboard => Google::Apis::ContainerV1beta1::KubernetesDashboard.new({
            :disabled => true,
          }),
          :network_policy_config => Google::Apis::ContainerV1beta1::NetworkPolicyConfig.new({
            :disabled => false,
          }),
        }),

        :maintenance_policy => Google::Apis::ContainerV1beta1::MaintenancePolicy.new({
          :window => Google::Apis::ContainerV1beta1::MaintenanceWindow.new({
            :daily_maintenance_window => Google::Apis::ContainerV1beta1::DailyMaintenanceWindow.new({
              :start_time => o[:maintenance_window],
            }),
          }),
        }),

        #
        ## Authentication
        #
        :master_auth => Google::Apis::ContainerV1beta1::MasterAuth.new({
          :client_certificate_config => Google::Apis::ContainerV1beta1::ClientCertificateConfig.new({
            :issue_client_certificate => false,
          }),
        }),

        #
        ## Network
        #
        :ip_allocation_policy => Google::Apis::ContainerV1beta1::IpAllocationPolicy.new({
          :cluster_ipv4_cidr_block  => o[:cluster_ipv4_cidr],
          :create_subnetwork        => o["create_subnetwork"],
          :services_ipv4_cidr_block => o[:services_ipv4_cidr],
          :subnetwork_name          => o[:subnetwork],
          :use_ip_aliases           => true,
        }),
        :locations => locations,

        #
        ## Features
        #
        :monitoring_service => ("monitoring.googleapis.com/kubernetes" if o[:enable_monitoring]),
        :logging_service    => ("logging.googleapis.com/kubernetes" if o[:enable_logging]),

        :binary_authorization => Google::Apis::ContainerV1beta1::BinaryAuthorization.new({
          :enabled => o[:enable_binary_authorization],
        }),
        :legacy_abac => Google::Apis::ContainerV1beta1::LegacyAbac.new({
          :enabled => false,
        }),
        :network_policy => Google::Apis::ContainerV1beta1::NetworkPolicy.new({
          :enabled => o[:enable_network_polices],
        }),
        :pod_security_policy_config => Google::Apis::ContainerV1beta1::PodSecurityPolicyConfig.new({
          :enabled => o[:enable_pod_security_polices],
        }),

        #
        ## Node Pools
        #
        :node_pools => [
          Google::Apis::ContainerV1beta1::NodePool.new({
            :autoscaling  => Google::Apis::ContainerV1beta1::NodePoolAutoscaling.new({
              :autoprovisioned => false,
              :enabled         => o[:enable_autoscaler],
              :max_node_count  => o[:max_nodes],
              :min_node_count  => o[:size],
            }),
            :config => Google::Apis::ContainerV1beta1::NodeConfig.new({
              :disk_size_gb => o[:disk_size_gb],
              :image_type   => o[:image_type],
              :machine_type => o[:machine_type],
              :oauth_scopes => [
                "https://www.googleapis.com/auth/compute",
                "https://www.googleapis.com/auth/devstorage.read_only",
                "https://www.googleapis.com/auth/logging.write",
                "https://www.googleapis.com/auth/monitoring",
              ],
              :preemptible => o[:preemptible],
            }),
            :initial_node_count => o[:size],
            :locations          => locations,
            :management         => Google::Apis::ContainerV1beta1::NodeManagement.new({
              :auto_repair  => o[:enable_autorepair],
              :auto_upgrade => o[:enable_autoupgrade],
            }),
            :max_pods_constraint => Google::Apis::ContainerV1beta1::MaxPodsConstraint.new({
              :max_pods_per_node => 110,
            }),
            :name         => "compute",
            :version      => o[:version]
          }),
        ],
      })
      request.cluster = cluster

      if o[:enable_private_network]
        cluster.private_cluster = true
        cluster.private_cluster_config = Google::Apis::ContainerV1beta1::PrivateClusterConfig.new({
          :enable_private_endpoint => o[:enable_private_endpoint],
          :enable_private_nodes    => true,
          :master_ipv4_cidr_block  => o[:master_ipv4_cidr_block],
        })

        # @step: do we have any authorized cidr's
        if o[:authorized_master_cidrs].size > 0
          cluster.master_authorized_networks_config = Google::Apis::ContainerV1beta1::MasterAuthorizedNetworksConfig.new({
            :cidr_blocks => [],
            :enabled     => true
          })
          o[:authorized_master_cidrs].each do |x|
            cluster.master_authorized_networks_config.cidr_blocks.push(Google::Apis::ContainerV1beta1::CidrBlock.new({
              :cidr_block   => x[:cidr],
              :display_name => x[:name],
            }))
          end
        end

        # @step: attempt to provision the cluster
        gke.create_project_location_cluster("projects/#{@project}/locations/#{@region}", request) do |x, exception|
          raise exception unless exception.nil?
          wait(x.name)
        end
      end
    end

    # @step: wait on the api to become available
    wait_on_api(name)

    # @step: get the cluster endpoint
    cluster = list_clusters().select { |x| x.name = name }.first
    token = authorize.access_token

    # @step: if private networking we need to provision a cloud-nat
    if o[:enable_pod_security_polices]
      kubectl(cluster.endpoint, token, DefaultPspClusterRole)
      kubectl(cluster.endpoint, token, DefaultPspClusterRoleBinding)
    end

    # @step: apply the default cluster admin
    kubectl(cluster.endpoint, token, DefaultClusterAdminRole)
    kubectl(cluster.endpoint, token, DefaultClusterAdminBinding)
  end

  # destroy is responsible for deleting a gke cluster
  def destroy(name, project = @project, region = @region)
    # @step: check the cluster exists
    raise Exception.new("the cluster: #{name} does not exist") unless exist?(name)

    gke.delete_project_location_cluster("projects/#{project}/locations/#{region}/clusters/#{name}")
  end

  private
  def exist?(name, project = @project, region = @region)
    list_clusters(project, region).map { |x| x.name }.include?(name)
  end

  # wait_on_api is responsible for waiting the api is available
  def wait_on_api(name, project = @project, region = @region)
    # @step: check the cluster exists
    raise ArgumentError.new("cluster does not exist") unless exist?(name, project, region)
    # @step: grab the cluster
    cluster = list_clusters(project, region).select { |x| x.name = name }.first

    client  = kube_client(cluster.endpoint)
    max_attempts = 60
    attempts = 0

    # @step: wait for the api to be available
    while true do
      begin
        break if client.get_services(namespace: "default").size >= 0
      rescue Exception
        attempts += 1
        sleep(5)
        raise Exception.new("timed out waiting for the api") if attempts >= max_attempts
      end
    end
  end

  # wait is responisble for waiting for an operation to complete or error
  def wait(id)
    interval = 10
    max_timeout = 15 * 60
    max_attempts = max_timeout / interval
    attempts = 0
    retries = 0

    # @TODO this feels like a very naive timeout, but i don't know ruby too well so :-)
    while true do
      begin
        resp = get_operation_status(id)
        if !resp.nil? and resp.status == "DONE"
          if not resp.status_message.nil? and not resp.status_message.empty?
            raise Exception.new("operation: #{x.operation_type} has failed with error message: #{resp.status_message}")
          end
          break
        end
        # @step: throw an exception if we've overrun the max attempts
        raise Exception.new("operation: #{x.operation_type}, target: #{x.target_link} has timed out") if attempts > max_attempts
        sleep(interval)
        attempts += 1
      rescue Exception => exception
        raise exception unless retries < 3
        retries += 1
        sleep(5)
      end
    end
  end

  def get_operation_status(id, project = @project, region = @region)
    gke.get_project_location_operation("projects/#{project}/locations/#{region}/operations/*", operation_id: id)
  end

  def list_clusters(project = @project, region = @region)
    gke.list_zone_clusters(nil, nil, parent: "projects/#{project}/locations/#{region}").clusters || []
  end

  def list_locations(region = @region, project = @project)
    gke.list_project_locations("projects/#{project}").locations.select { |x|
      x.name.start_with?("#{region}-")
    }.map { |x| x.name }
  end

  # authorize is responsible for providing an access token to operate
  def authorize
    unless defined?(@credentials)
      @authorizer ||= Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: StringIO.new(@account),
        scope:       'https://www.googleapis.com/auth/cloud-platform',
      )
      @credentials = @authorizer.fetch_access_token!
    end
    @authorizer
  end

  def kubectl(endpoint, token, manifest)
    endpoint = "https://#{endpoint}" unless endpoint.start_with?("https")
    command  = "kubectl --kubeconfig='' --insecure-skip-tls-verify=true --server=#{endpoint} --token=#{token} apply -f -"

    IO.popen(command, "r+") do |pipe|
      pipe.puts manifest
    end

    raise Exception.new("failed to run kubectl command") if $?.exitstatus
  end

  # network? checks if the network exists in the region and project
  def network?(name, project = @project, region = @region)
    networks(project, region).items.map { |x| x.name }.include?(name)
  end

  # networks returns a list of networks in the region and project
  def networks(project = @project, region = @region)
    compute.list_networks(region)
  end

  # subnet? checks if the subnet exists in the project, network and region
  def subnet?(name, network, project = @project, region = @region)
    subnets.include?(network)
  end

  # subnets returns a list of subnets in the network
  def subnets(network, region = @region, project = @project)
    compute.list_subnets(project, region).select { |x|
      x.network.end_with?(network)
    }.map { |x| x.name }
  end

  def kube_client(endpoint)
    endpoint     = "https://#{endpoint}" unless endpoint.start_with?("https")
    auth_options = { bearer_token: authorize.access_token   }
    ssl_options  = { verify_ssl:  OpenSSL::SSL::VERIFY_NONE }
    timeouts     = { open: 3, read: 5 }

    Kubeclient::Client.new(endpoint, 'v1', auth_options: auth_options, ssl_options: ssl_options, timeouts: timeouts)
  end

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

  def parent
    "projects/#{@project}/locations/#{@region}"
  end
end

require 'pp'

account = File.read('../../account.json')
region = "europe-west2"
project = "gke-learning-242311"

c = GKEAgent.new(account, project, region)
cluster = c.provision("test1", "just a test")

