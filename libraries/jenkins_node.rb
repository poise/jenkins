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
    actions(:install)

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
    rescue RestClient::Exception
      raise "Node not yet registered"
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

    def action_install
      include_recipe 'java'
      converge_by("create Jenkins node #{new_resource.node_name} at #{new_resource.path}") do
        save_node_data
        notifying_block do
          create_group
          create_user
          create_directory
        end
        create_slave
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

    def save_node_data
      # Store the data back to the chef-server so we can reconstitute it later
      data = %w{node_name description path executors mode availability
        in_demand_delay idle_delay labels}.inject({}) do |memo, key|
        memo[key] = new_resource.send(key)
        memo
      end
      if Chef::Config[:solo]
        # No server, so cram it somewhere just in case
        node.set['jenkins']['nodes'][new_resource.node_name] = data
      else
        node_data = chef_server_rest.get_rest("nodes/#{node.name}")
        node_data['normal'] ||= {}
        node_data['normal']['jenkins'] ||= {}
        node_data['normal']['jenkins']['nodes'] ||= {}
        node_data['normal']['jenkins']['nodes'][new_resource.node_name] = data
        chef_server_rest.put_rest("nodes/#{node.name}", node_data)
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
