#
# Author:: Doug MacEachern <dougm@vmware.com>
# Author:: Fletcher Nichol <fnichol@nichol.ca>
# Author:: Noah Kantrowitz <noah@coderanger.net>
#
# Copyright 2010, VMware, Inc.
# Copyright 2013, Balanced, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'rexml/document'
require 'uri'
require 'rest-client'

require File.expand_path('../jenkins', __FILE__)

class JenkinsAPI
  def initialize(url, username=nil, password=nil)
    @raw_url = url
    @username = username
    @password = password
    @raw_url.chop! if @raw_url[-1] == '/'
    @url = URI(@raw_url)
    @url.user = @username
    @url.password = @password
  end

  def url
    @url.to_s
  end

  def get(path)
    Chef::Log.debug("[jenkins-api] Requesting '#{url + path}'")
    format_rest_client_error do
      RestClient.get(url + path)
    end
  end

  def post(path, params={})
    # Check for crumbs
    begin
      crumb_data = get_json('/crumbIssuer/api/json/')
      params[crumb_data['crumbRequestField']] = crumb_data['crumb']
    rescue RestClient::ResourceNotFound
      # Crumbs not enabled
    end
    Chef::Log.debug("[jenkins-api] Posting to '#{url + path}' with #{params.inspect}")
    format_rest_client_error do
      RestClient.post(url + path, params)
    end
  end

  def get_json(path)
    Chef::JSONCompat.from_json(get(path).to_str, create_additions: false)
  end

  private

  def format_rest_client_error(&block)
    block.call
  rescue RestClient::Exception => e
    Chef::Log.debug("[jenkins-api] Error #{e.http_code}: #{e.http_body}")
    raise
  end
end

class Chef
  class Resource::JenkinsNode < Resource
    include Poise(parent: Jenkins, parent_optional: true)
    actions(:create, :delete, :connect, :disconnect, :online, :offline)

    attribute(:node_name, kind_of: String, default: lazy { name.split('::').last })
    attribute(:path, kind_of: String, default: lazy { node['jenkins']['node']['home'] })
    attribute(:log_path, kind_of: String, default: lazy { node['jenkins']['node']['log_dir'] })
    attribute(:description, kind_of: String, default: lazy { node['jenkins']['node']['description'] })
    attribute(:user, kind_of: String, default: lazy { node['jenkins']['node']['user'] })
    attribute(:group, kind_of: String, default: lazy { node['jenkins']['node']['group'] })
    attribute(:service_name, kind_of: String, default: lazy { "jenkins-slave-#{node_name}" })

    attribute(:server_url, kind_of: String, default: lazy { (parent && parent.url) || node['jenkins']['node']['server_url'] })
    attribute(:server_username, kind_of: String, default: lazy { node['jenkins']['node']['server_username'] })
    attribute(:server_password, kind_of: String, default: lazy { node['jenkins']['node']['server_password'] })
    attribute(:jnlp_secret, kind_of: String, default: lazy { parse_jnlp_secret })
    attribute(:executors, kind_of: Integer, default: lazy { node['jenkins']['node']['executors'] })
    attribute(:mode, equal_to: %w(normal exclusive), default: lazy { node['jenkins']['node']['mode'] })
    attribute(:labels, kind_of: Array, default: lazy { [] })
    attribute(:auto_labels, equal_to: [true, false], default: true)
    attribute(:availability, equal_to: %w(always demand), default: lazy { node['jenkins']['node']['availability'] })
    attribute(:jvm_options, kind_of: String, default: lazy { node['jenkins']['node']['jvm_options'] })
    attribute(:in_demand_delay, kind_of: Integer, default: lazy { node['jenkins']['node']['in_demand_delay'] }) # Only used when availability==demand
    attribute(:idle_delay, kind_of: Integer, default: lazy { node['jenkins']['node']['idle_delay'] }) # Only used when availability==demand
    attribute(:env, kind_of: Hash, default: lazy { node['jenkins']['node']['env'] })
    # Not making a new subclass just for this since frequent overrides seem unlikely (famous last words)
    attribute(:winsw_url, kind_of: String, default: lazy { node['jenkins']['node']['winsw_url'] })

    def slave_jar
      ::File.join(path, 'slave.jar')
    end

    # For Windows
    def slave_exe
      ::File.join(path, 'jenkins-slave.exe')
    end

    def api
      @api ||= JenkinsAPI.new(server_url, server_username, server_password)
    end

    def parse_jnlp_secret
      doc = REXML::Document.new(api.get("/computer/#{node_name}/slave-agent.jnlp").to_str)
      doc.elements.each('//application-desc/argument') do |elem|
        if elem.text =~ /[0-9a-f]{64}/
          return elem.text
        end
      end
    end

    def after_created
      super
      # # Write the username and password into the URL
      # url = URI(server_url)
      # url.user = server_user
      # url.password = server_password
      # url.path << '/' unless url.path[-1] == '/'
      # server_url(url.to_s)
      # Automatic labels to help with job targetting
      if auto_labels
        extra_labels = [
          node['platform'], # ubuntu
          node['platform_family'], # debian
          node['platform_version'], # 10.04
          "#{node['platform']}-#{node['platform_version']}", # ubuntu-10.04
          node['kernel']['machine'], # x86_64
          node['os'], # linux
          node['os_version'], # 2.6.32-38-server
        ]
        extra_labels += node['tags']
        extra_labels << node['virtualization']['system'] if node.attribute?('virtualization') # xen
        labels(labels + extra_labels)
        labels.uniq!
      end
    end

  end

  class Resource::JenkinsNodeSsh < Resource::JenkinsNode
    attribute(:ssh_host, kind_of: String, default: lazy { node['jenkins']['node']['ssh_host'] })
    attribute(:ssh_port, kind_of: Integer, default: lazy { node['jenkins']['node']['ssh_port'] })
    attribute(:ssh_user, kind_of: String, default: lazy { node['jenkins']['node']['ssh_user'] || user })
    attribute(:ssh_password, kind_of: String, default: lazy { node['jenkins']['node']['ssh_password'] })
    attribute(:ssh_private_key, kind_of: String, default: lazy { node['jenkins']['node']['ssh_private_key'] })
    attribute(:ssh_shell, kind_of: String, default: lazy { node['jenkins']['node']['shell'] })
    attribute(:server_pubkey, kind_of: String, default: lazy { search_for_server_pubkey })

    def search_for_server_pubkey
      unless Chef::Config[:solo]
        raise 'Searching for the server pubkey not yet implemented'
      end
    end
  end

  class Provider::JenkinsNode < Provider
    include Poise
    attr_accessor :jnlp_secret

    def action_create
      include_recipe 'java'
      converge_by("create Jenkins node #{new_resource.node_name} at #{new_resource.path}") do
        notifying_block do
          create_group
          create_user
          create_directory
        end
        configure_jenkins_node
        create_slave
      end
    end

    def action_delete
      converge_by("delete Jenkins node #{new_resource.node_name}") do
        notifying_block do
          delete_node
        end
      end
    end

    def action_connect
      converge_by("connect Jenkins node #{new_resource.node_name}") do
        notifying_block do
          connect_node
        end
      end
    end

    def action_disconnect
      converge_by("disconnect Jenkins node #{new_resource.node_name}") do
        notifying_block do
          delete_node
        end
      end
    end

    def action_online
      converge_by("online Jenkins node #{new_resource.node_name}") do
        notifying_block do
          online_node
        end
      end
    end

    def action_offline
      converge_by("offline Jenkins node #{new_resource.node_name}") do
        notifying_block do
          offline_node
        end
      end
    end

    def api
      new_resource.api
    end

    private

    def create_group
      group new_resource.group
    end

    def create_user
      user new_resource.user do
        comment 'Jenkins CI node'
        gid new_resource.group
        home new_resource.path
      end
    end

    def create_directory
      directory new_resource.path do
        owner new_resource.user
        group new_resource.group
      end
    end

    def launcher_data
      {'stapler-class' => 'hudson.slaves.JNLPLauncher'}
    end

    def configure_jenkins_node
      node_properties = {
        'stapler-class-bag' => 'true',
      }
      if new_resource.env && !new_resource.env.empty?
        node_properties['hudson-slaves-EnvironmentVariablesNodeProperty'] = {
          'env' => new_resource.env.map{|key, value| {'key' => key, 'value' => value}},
        }
      end

      retention_strategy = if new_resource.availability == 'always'
        {'stapler-class' => 'hudson.slaves.RetentionStrategy$Always'}
      else
        {
          'stapler-class' => 'hudson.slaves.RetentionStrategy$Demand',
          'inDemandDelay' => new_resource.in_demand_delay.to_s,
          'idleDelay' => new_resource.idle_delay.to_s,
        }
      end

      node_data = {
        "name" => new_resource.node_name,
        "nodeDescription" => new_resource.description,
        "numExecutors" => new_resource.executors.to_s,
        "remoteFS" => new_resource.path,
        "labelString" => new_resource.labels.join(' '),
        "mode" => new_resource.mode.upcase,
        "type" => "hudson.slaves.DumbSlave$DescriptorImpl",
        "retentionStrategy" => retention_strategy,
        "nodeProperties" => node_properties,
        "launcher" => launcher_data, # This is a method on the provider so subclasses can override
      }

      begin
        api.get("/computer/#{new_resource.node_name}")
        exists = true
      rescue RestClient::ResourceNotFound
        exists = false
      end

      begin
        if exists
          # Update existing node data
          api.post("/computer/#{new_resource.node_name}/configSubmit", json: node_data.to_json)
        else
          api.post('/computer/doCreateItem', name: new_resource.node_name, type: 'hudson.slaves.DumbSlave$DescriptorImpl', json: node_data.to_json)
        end
      rescue RestClient::Found
        # This space left intentionally blank
      end
    end

    def create_slave
      notifying_block do
        download_slave
        configure_service
      end
    end

    def download_slave
      remote_file new_resource.slave_jar do
        source "#{api.url}/jnlpJars/slave.jar"
        owner new_resource.user
        notifies :restart, "runit_service[#{new_resource.service_name}]"
      end
    end

    def service_resource
      include_recipe 'runit'

      @service_resource ||= runit_service new_resource.service_name do
        cookbook 'jenkins'
        run_template_name 'jenkins-slave'
        log_template_name 'jenkins-slave'
        options new_resource: new_resource
      end
    end

    def configure_service
      service_resource
    end

    # All this jenkins_cli stuff won't work against authenticated servers
    def delete_node
      jenkins_cli "delete-node #{new_resource.node_name}" do
        url new_resource.server_url
        path new_resource.path
      end
    end

    def connect_node
      jenkins_cli "connect-node #{new_resource.node_name}" do
        url new_resource.server_url
        path new_resource.path
      end
    end

    def disconnect_node
      jenkins_cli "disconnect-node #{new_resource.node_name}" do
        url new_resource.server_url
        path new_resource.path
      end
    end

    def online_node
      jenkins_cli "online-node #{new_resource.node_name}" do
        url new_resource.server_url
        path new_resource.path
      end
    end

    def offline_node
      jenkins_cli "offline-node #{new_resource.node_name}" do
        url new_resource.server_url
        path new_resource.path
      end
    end
  end

  class Provider::JenkinsNodeSsh < Provider::JenkinsNode
    def create_user
      r = super
      r.shell new_resource.ssh_shell
      r
    end

    def create_directory
      r = super
      create_ssh_dir
      create_authorized_keys
      r
    end

    def create_ssh_dir
      directory ::File.join(new_resource.path, '.ssh') do
        owner new_resource.user
        group new_resource.group
        mode '700'
      end
    end

    def create_authorized_keys
      file ::File.join(new_resource.path, '.ssh', 'authorized_keys') do
        content new_resource.server_pubkey
        owner new_resource.user
        group new_resource.group
        mode '600'
      end
    end

    def create_slave
      # SSH has no explicit slave service
    end

    def launcher_groovy
      password = if new_resource.password.nil?
        'null'
      else
        %Q("#{new_resource.password}")
      end
      %Q(new_ssh_launcher(["#{new_resource.ssh_host}", #{new_resource.ssh_port}, "#{new_resource.ssh_user}", #{password},
                           "#{new_resource.ssh_private_key}", "#{new_resource.jvm_options}"] as Object[]))
    end
  end

  class Provider::JenkinsNodeWindows < Provider::JenkinsNode
    def create_group
    end

    def create_user
    end

    def create_directory
      directory new_resource.path # Minor repition but you can't set attrs to nil
    end

    def service_resource
      @service_resource ||= service new_resource.service_name
    end

    def configure_service
      download_winsw
      configure_winsw
      install_service
      authorize_service
      start_service
    end

    def download_winsw
      remote_file new_resource.slave_exe do
        source new_resource.winsw_url
      end
    end

    def configure_winsw
    end
  end
end
