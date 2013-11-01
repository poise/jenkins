#
# Author:: AJ Christensen <aj@junglist.gen.nz>
# Author:: Dough MacEachern <dougm@vmware.com>
# Author:: Fletcher Nichol <fnichol@nichol.ca>
# Author:: Seth Chisamore <schisamo@opscode.com>
# Author:: Guilhem Lettron <guilhem.lettron@youscribe.com>
# Author:: Noah Kantrowitz <noah@coderanger.net>
#
# Copyright 2010, VMWare, Inc.
# Copyright 2012, Opscode, Inc.
# Copyright 2013, Youscribe.
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

require 'open-uri'

require 'chef/dsl/recipe'
require 'chef/mixin/shell_out'

require File.expand_path('../jenkins_utils', __FILE__)

class Chef
  class Resource::Jenkins < Resource::LWRPBase
    include Poise
    include Poise::Resource::SubResourceContainer
    include Chef::DSL::Recipe
    include JenkinsUtils
    self.resource_name = :jenkins
    default_action(:install)
    actions(:uninstall, :wait_until_up, :restart)

    attribute(:path, kind_of: String, name_attribute: true)
    def version(arg=nil)
      # If we are reading, grab the actual latest version
      if !arg && (!@version || @version == 'latest')
        @version = update_center['core']['version']
      end
      set_or_return(:version, arg, kind_of: String, default: 'latest')
    end
    def war_url(arg=nil)
      val = set_or_return(:war_url, arg, kind_of: String, default: node['jenkins']['server']['war_url'])
      # Interpolate the version if needed
      if !arg && val
        @war_url = (val %= {version: self.version})
      end
      val
    end
    attribute(:log_dir, kind_of: String, default: lazy { node['jenkins']['server']['log_dir'] })
    attribute(:service_name, kind_of: String, default: lazy { node['jenkins']['server']['service_name'] })
    attribute(:user, kind_of: String, default: lazy { node['jenkins']['server']['user'] })
    attribute(:group, kind_of: String)
    attribute(:home_dir_group, kind_of: String)
    attribute(:plugins_dir_group, kind_of: String)
    attribute(:ssh_dir_group, kind_of: String)
    attribute(:log_dir_group, kind_of: String)
    attribute(:dir_permissions, kind_of: String, default: lazy { node['jenkins']['server']['dir_permissions'] })
    attribute(:ssh_dir_permissions, kind_of: String, default: lazy { node['jenkins']['server']['ssh_dir_permissions'] })
    attribute(:log_dir_permissions, kind_of: String)
    attribute(:host, kind_of: String, default: lazy { node['jenkins']['server']['host'] })
    attribute(:port, kind_of: [String, Integer], default: lazy { node['jenkins']['server']['port'] })
    attribute(:url, kind_of: String, default: lazy { node['jenkins']['server']['url'] || "http://#{host}:#{port}" })

    def after_created
      super
      run_context.resource_collection.each do |res|
        if res.is_a?(self.class) && res.service_name == self.service_name
          raise "#{res} already uses service name #{self.service_name}"
        end
      end
    end

    def war_path
      ::File.join(self.path, "jenkins-#{self.version}.war")
    end

    def method_missing(method_symbol, *args, &block)
      super(:"jenkins_#{method_symbol}", *args, &block)
    end

  end

  class Provider::Jenkins < Provider::LWRPBase
    include Poise
    include Chef::Mixin::ShellOut

    def initialize(*args)
      super
      initialize_resource_defaults
    end

    def whyrun_supported?
      true
    end

    def action_install
      include_recipe 'java'
      notifying_block do
        create_group
        create_user
        create_home_dir
        create_plugins_dir
        create_log_dir
        create_ssh_dir
        install_jenkins
        configure_service
      end
      action_wait_until_up
    end

    def action_uninstall
      notifying_block do
        remove_service
        uninstall_jenkins
        remove_log_dir
        remove_home_dir
        remove_user
        remove_group
      end
    end

    def action_wait_until_up
      Chef::Log.info "Waiting until Jenkins is listening on port #{new_resource.port}"
      until service_listening?
        sleep 1
        Chef::Log.debug('.')
      end

      Chef::Log.info 'Waiting until the Jenkins API is responding'
      until endpoint_responding?
        sleep 1
        Chef::Log.debug('.')
      end
    end

    def action_restart
      sub_resource_block do
        service_resource.run_action(:restart)
      end
      action_wait_until_up
    end

    private

    def initialize_resource_defaults
      %w{home_dir_group plugins_dir_group ssh_dir_group plugins_dir_group log_dir_group log_dir_permissions}.each do |key|
        @new_resource.send(key, node['jenkins']['server'][key]) unless @new_resource.send(key)
      end
    end

    def create_group
      group new_resource.group do
        system true
      end if new_resource.group
    end

    def create_user
      user new_resource.user do
        comment "Jenkins service user for #{new_resource.path}"
        gid new_resource.group if new_resource.group
        system true
        shell '/bin/false'
        home new_resource.path
      end
    end

    def create_home_dir
      directory new_resource.path do
        owner new_resource.user
        group new_resource.home_dir_group
        mode new_resource.dir_permissions
      end
    end

    def create_plugins_dir
      directory ::File.join(new_resource.path, 'plugins') do
        owner new_resource.user
        group new_resource.plugins_dir_group
        mode new_resource.dir_permissions
      end
    end

    def create_log_dir
      directory new_resource.log_dir do
        owner new_resource.user
        group new_resource.log_dir_group
        mode new_resource.log_dir_permissions
      end
    end

    def create_ssh_dir
      directory ::File.join(new_resource.path, '.ssh') do
        owner new_resource.user
        group new_resource.ssh_dir_group
        mode new_resource.ssh_dir_permissions
      end
    end

    def install_jenkins
      remote_file new_resource.war_path do
        source new_resource.war_url
        owner new_resource.user
        group new_resource.group
        mode '644'
      end
    end

    def generate_ssh_key
      ssh_key_path = ::File.join(new_resource.path, '.ssh', 'id_rsa')
      execute "ssh-keygen -f #{ssh_key_path} -N ''" do
        user new_resource.user
        group new_resource.ssh_dir_group
        not_if { ::File.exists?(ssh_key_path) }
      end

      ruby_block 'store_server_ssh_pubkey' do
        block do
          node.set['jenkins']['server']['pubkey'] = IO.read(ssh_key_path)
        end
      end
    end

    def service_resource
      include_recipe 'runit'

      @service_resource ||= runit_service new_resource.service_name do
        options new_resource: new_resource
      end
    end

    def configure_service
      service_resource
    end

    def remove_group
      # TODO
    end

    def remove_user
      # TODO
    end

    def remove_home_dir
      directory new_resource.path do
        action :remove
      end
    end

    def remove_log_dir
      directory new_resource.log_dir do
        action :remove
      end
    end

    def uninstall_jenkins
    end

    def remove_service
      # TODO
    end

    # Helpers used to check if Jenkins is available
    def service_listening?
      cmd = shell_out!('netstat -lnt')
      cmd.stdout.each_line.select do |l|
        l.split[3] =~ /#{new_resource.port}/
      end.any?
    end

    def endpoint_responding?
      url = "#{new_resource.url}/api/json"
      response = Chef::REST::RESTRequest.new(:GET, URI.parse(url), nil).call
      if response.kind_of?(Net::HTTPSuccess) ||
            response.kind_of?(Net::HTTPOK) ||
            response.kind_of?(Net::HTTPRedirection) ||
            response.kind_of?(Net::HTTPForbidden)
        Chef::Log.debug("GET to #{url} successful")
        return true
      else
        Chef::Log.debug("GET to #{url} returned #{response.code} / #{response.class}")
        return false
      end
    rescue EOFError, Errno::ECONNREFUSED
      Chef::Log.debug("GET to #{url} failed with connection refused")
      return false
    end

    # Provider subclass to implement package-based installs
    class Package < Jenkins
      private
      def initialize_resource_defaults
        resource_defaults.each do |key, value|
          @new_resource.send(key, value) unless @new_resource.send(key)
        end
      end

      def configure_repository
        # Overridden in subclasses
      end

      def install_jenkins
        configure_repository
        package 'jenkins' do
          version new_resource.version
        end
      end

      def uninstall_jenkins
        package 'jenkins' do
          action :remove
        end
      end

      def configure_service
        service_resource.action [:start, :enable]
      end

      def remove_service
        service_resource.action [:stop, :disable]
      end

      def service_resource
        @service_resource ||= service new_resource.service_name do
          supports :status => true, :restart => true, :reload => true
          action :nothing
        end
      end

    end

    class AptPackage < Package
      def resource_defaults
        {
          log_dir_permissions: '755',
          home_dir_group: 'adm',
          log_dir_group: 'adm',
          ssh_dir_group: 'nogroup',
        }
      end

      def configure_repository
        include_recipe 'apt'

        apt_repository 'jenkins' do
          uri 'http://pkg.jenkins-ci.org/debian'
          distribution 'binary/'
          components ['']
          key 'http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key'
          action :add
        end
      end

    end

    class YumPackage < Package
      def resource_defaults
        {
          group: new_resource.user,
          log_dir_permissions: '750',
          home_dir_group: new_resource.user,
          log_dir_group: new_resource.user,
          ssh_dir_group: new_resource.user,
        }
      end

      def configure_repository
        include_recipe 'yum'

        yum_key 'RPM-GPG-KEY-jenkins-ci' do
          url 'http://pkg.jenkins-ci.org/redhat/jenkins-ci.org.key'
          action :add
        end

        yum_repository 'jenkins-ci' do
          url 'http://pkg.jenkins-ci.org/redhat'
          key 'RPM-GPG-KEY-jenkins-ci'
          action :add
        end
      end

    end

  end
end
