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

require File.expand_path('../jenkins', __FILE__)

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

    def node_info_groovy
      ::File.join(path, 'node_info.groovy')
    end

    def manage_node_groovy
      ::File.join(path, "manage_#{node_name}.groovy")
    end

    def after_created
      super
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

    def server_pubkey
      raise "SOMETHING HERE"
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
          create_node_info_groovy
          configure_jenkins_node
          create_slave
        end
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

    def create_node_info_groovy
      cookbook_file new_resource.node_info_groovy do
        source 'node_info.groovy'
        cookbook 'jenkins'
        owner 'root'
        group 'root'
        mode '644'
      end
    end

    def launcher_groovy
      'new JNLPLauncher()'
    end

    def configure_jenkins_node
      manage = jenkins_cli "groovy #{new_resource.manage_node_groovy}" do
        url new_resource.server_url
        path new_resource.path
        action :nothing
      end
      launcher = launcher_groovy

      template new_resource.manage_node_groovy do
        source 'manage_node.groovy.erb'
        cookbook 'jenkins'
        owner 'root'
        group 'root'
        mode '600'
        variables new_resource: new_resource, launcher: launcher
        notifies :run, manage, :immediately
      end
    end

    def create_slave
      download_slave
      find_jnlp_secret
      configure_service
    end

    def download_slave
      r = service_resource # Fracking scoping rules will be the death of me
      remote_file new_resource.slave_jar do
        source "#{new_resource.server_url}/jnlpJars/slave.jar"
        owner new_resource.user
        notifies :restart, r, :immediately
      end
    end

    def find_jnlp_secret
      self_ = self
      jenkins_cli "node_info for #{new_resource.node_name} to get jnlp secret" do
        url new_resource.server_url
        path new_resource.path
        command "groovy node_info.groovy #{new_resource.node_name}"
        block do |stdout|
          current_node = JSON.parse(stdout)
          self_.jnlp_secret = current_node['secret'] if current_node['secret']
        end
      end
    end

    def service_resource
      include_recipe 'runit'

      @service_resource ||= runit_service new_resource.service_name do
        cookbook 'jenkins'
        run_template_name 'jenkins-slave'
        log_template_name 'jenkins-slave'
        options new_resource: new_resource, jnlp_secret: jnlp_secret
      end
    end

    def configure_service
      service_resource
    end

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
