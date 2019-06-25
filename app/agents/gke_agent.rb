require 'google/apis/container_v1beta1'
require 'googleauth'
require 'json'
require 'openssl'

class GKEAgent
  DefaultPodBinding = <<-EOF
---
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
---
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

  DefaultClusterAdminBinding = <<-EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin
  namespace: kube-system
---
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

  def initialize(account:, project:, region:)
    @account = JSON.parse(account)
    @project = project
    @region = region
  end

  def provision(name, description, options = {})
    # @step: merge the default options with user defined ones
    o = default_options.merge(options)

    # @step: we check if the cluster already exists
    unless exist?(name)
      # @step: get a list of location within the region
      locations = client.list_locations(@region)

      c = Google::Container::V1beta1::Cluster.new({
        :name                    => name,
        :description             => description,
        :initial_cluster_version => o[:version],

        #
        ## Addons
        #
        :addons_config  => Google::Container::V1beta1::AddonsConfig.new({
          :http_load_balancing => Google::Container::V1beta1::HttpLoadBalancing.new({
            :disabled => !o[:enable_http_loadbalancer]
          }),
          :horizontal_pod_autoscaling => Google::Container::V1beta1::HorizontalPodAutoscaling.new({
            :disabled => !o[:enable_horizontal_pod_autoscaler],
          }),
          :istio_config => Google::Container::V1beta1::IstioConfig.new({
            :auth     => Google::Container::V1beta1::IstioConfig::IstioAuthMode.AUTH_MUTUAL_TLS,
            :disabled => !o[:enable_istio],
          }),
          :kubernetes_dashboard => Google::Container::V1beta1::KubernetesDashboard.new({
            :disabled => true,
          }),
          :network_policy_config => Google::Container::V1beta1::NetworkPolicyConfig.new({
            :disabled => false,
          }),
        }),

        :maintenance_policy      => Google::Container::V1beta1::MaintenancePolicy.new({
          :window => Google::Container::V1beta1::MaintenanceWindow({
            :daily_maintenance_window => Google::Container::V1beta1::DailyMaintenanceWindow.new({
              :start_time => o[:maintenance_window],
            }),
          }),
        }),

        #
        ## Authentication
        #
        :master_auth => Google::Container::V1beta1::MasterAuth.new({
          :client_certificate_config => Google::Container::V1beta1::ClientCertificateConfig.new({
            :issue_client_certificate => false,
          }),
        }),

        #
        ## Network
        #
        :cluster_ipv4_cidr_block  => o[:cluster_ipv4_cidr],
        :ip_allocation_policy     => Google::Container::V1beta1::IPAllocationPolicy.new({
          :use_ip_aliases => true,
        }),
        :locations      => locations,
        :network_config => Google::Container::V1beta1::NetworkConfig.new({
          :network    => o[:network],
          :subnetwork => o[:subnetwork],
        }),
        :services_ipv4_cidr_block => o[:services_ipv4_cidr],

        #
        ## Features
        #
        :monitoring_service => ("monitoring.googleapis.com/kubernetes" if o[:enable_monitoring]),
        :logging_service    => ("logging.googleapis.com/kubernetes" if o[:enable_logging]),

        :binary_authorization => Google::Container::V1beta1::BinaryAuthorization.new({
          :enabled => o[:enable_binary_authorization],
        }),
        :legacy_abac => Google::Container::V1beta1::LegacyAbac.new({
          :enabled => false,
        }),
        :network_policy => Google::Container::V1beta1::NetworkPolicy.new({
          :enabled => o[:enable_network_polices],
        }),
        :pod_security_policy_config => Google::Container::V1beta1::PodSecurityPolicyConfig.new({
          :enabled => o[:enable_pod_security_polices],
        }),

        #
        ## Node Pools
        #
        :node_pools => [
          Google::Container::V1beta1::NodePool.new({
            :autoscaling  => Google::Container::V1beta1::NodePoolAutoscaling.new({
              :autoprovisioned => false,
              :enabled         => o[:enable_autoscaler],
              :max_node_count  => i[:max_nodes],
              :min_node_count  => o[:size],
            }),
            :config => Google::Container::V1beta1::NodeConfig.new({
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
            :management         => Google::Container::V1beta1::NodeManagement.new({
              :auto_repair  => o[:enable_autorepair],
              :auto_upgrade => o[:enable_autoupgrade],
            }),
            :max_pods_constraint => Google::Container::V1beta1::MaxPodsConstraint.new({
              :max_pods_per_node => 110,
            }),
            :name         => "compute",
            :version      => o[:version]
          }),
        ],
      })

      if o[:enable_private_network]
        c.private_cluster = true
        c.private_cluster_config = Google::Container::V1beta1::PrivateClusterConfig.new({
          :enable_private_endpoint => o[:enable_private_endpoint],
          :enable_private_nodes    => true,
          :master_ipv4_cidr_block  => o[:master_ipv4_cidr_block],
        })

        # @step: do we have any authorized cidr's
        if o[:authorized_master_cidrs].size > 0
          c.master_authorized_networks_config = Google::Container::V1beta1::MasterAuthorizedNetworksConfig.new({
            :cidr_blocks => [],
            :enabled     => true
          })
          o[:authorized_master_cidrs].each do |x|
            c.master_authorized_networks_config.cidr_blocks.push(Google::Container::V1beta1::MasterAuthorizedNetworksConfig::CidrBlock.new({
              :cidr_block   => x["cidr"],
              :display_name => x["name"],
            }))
          end
        end
      end

      # @step: if private networking we need to provision a cloud-nat
      if o[:enable_private_nodes]



      end

      # @step: attempt to provision the cluster
      client.create_cluster(nil, nil, c, parent: "projects/#{@project}/locations/#{@region}") do |r, x|
        raise Exception.new("failed to create cluster: #{x.status_message}") unless x.status_message.empty?
      end

      # @step: we need to provision the default psp is enabled
      kubectl(DefaultPodBinding) if o[:enable_pod_security_polices]

      # @step: apply the default admin binding
      kubectl(DefaultClusterAdminBinding)
    end
  end


  def destroy(name)
    # @step: check the cluster exists
    unless exist?(name)
      raise Exception.new("the cluster: #{name} does not exist")
    end

    client.delete_cluster(nil, nil, "projects/#{@project}/locations/#{@region}/clusters/#{name}")
  end

  private
  def exist?(name)
    list_clusters.map { |x| x.name }.include?(name)
  end

  def list_clusters
    client.list_clusters(nil, nil, parent: "projects/#{@project}/locations/#{@region}")
  end

  def list_locations(region)
    client.list_locations("projects/#{@project}/locations/*").locations.select { |x|
      x.name.start_with?("#{region}-")
    }.map { |x| x.name }
  end

  def default_options
    {
      authorized_master_cidrs: [
        {name: "any",cidr: "0.0.0.0/0"},
      ],
      cluster_ipv4_cidr: "",
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
      maintenance_window: "03:00:00",
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

  def kubectl(manifest)
    unless defined?(@credentials)
      @authorizer ||= Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: @account,
        scope:       'https://www.googleapis.com/auth/cloud-platform',
      )
      # we have his for 60 minutes
      @credentials = @authorizer.fetch_access_token!
    end

    command = "kubectl --server=#{} --token=#{@credentials['access_token']} apply -f -"

    IO.popen(command, "r+") do |p|
      pipe.puts manifest
      pipe.gets
    end

    raise Exception.new("failed to run kubectl command") if $?.exitstatus
  end

  def network
    @network ||= Google::Cloud::Container(
      credentials: @account,
      version:     :v1beta1,
    )
  end

  # client returns the container client for us
  def client
    @client ||= Google::Cloud::Container(
      credentials: @account,
      version:     :v1beta1,
    )
  end
end
