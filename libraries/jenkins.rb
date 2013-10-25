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

class Chef
  class Resource::Jenkins < LWRPBase
    self.resource_name = :jenkins
    default_action(:install)
    actions(:uninstall)

    attribute(:path, kind_of: String, name_attribute: true)
    attribute(:version, kind_of: String, default: 'latest')
    attribute(:war_url, kind_of: String)
    attribute(:log_dir, kind_of: String)
    attribute(:service_name, kind_of: String)
    attribute(:user, kind_of: String)
    attribute(:group, kind_of: String)
    attribute(:home_dir_group, kind_of: String)
    attribute(:plugins_dir_group, kind_of: String)
    attribute(:ssh_dir_group, kind_of: String)
    attribute(:log_dir_group, kind_of: String)
    attribute(:dir_permissions, kind_of: String)
    attribute(:ssh_dir_permissions, kind_of: String)
    attribute(:log_dir_permissions, kind_of: String)

    def after_create
      # Initialize defaults from node attributes
      %w{war_url log_dir service_name user dir_permissions ssh_dir_permissions}.each do |key|
        self.send(key, node['jenkins']['server'][key]) unless self.send(key)
      end
      self.version(self.update_center['core']['version']) if self.version == 'latest'
      self.war_url(self.war_url % self.version) # Insert the version if needed

      self.group(node['jenkins']['server']['group']) unless self.group
      # TODO scan through the resource collection and ensure service_name is unique
      @subresources.each{|r| self.run_context.resource_collection.insert(r)} if @subresources
    end

    def plugin(name, &block)
      _subresource(Chef::Resource::JenkinsPlugin, name, &block)
    end

    def job(name, &block)
      _subresource(Chef::Resource::JenkinsJob, name, &block)
    end

    def update_center
      @update_center ||= begin
        data = open(node['jenkins']['server']['update_url']).read.split("\n")
        # Remove the first and last lines since those are actually Javascript code used for JSONP
        data.delete_at(0)
        data.delete_at(-1)
        Chef::JSONCompat.from_json(data.join("\n"), create_additions: false)
      end
    end

    private

    # TODO Fix ordering, they have to go after the current resource, can abuse after_created
    def _subresource(resource_class, name, &block)
      # From chef/dsl/recipe.rb
      resource = resource_class.new(name, self.run_context)
      resource.source_line = caller[1]
      resource.load_prior_resource
      resource.cookbook_name = self.cookbook_name
      resource.recipe_name = self.recipe_name
      resource.parent = self
      # Evaluate resource attribute DSL
      resource.instance_eval(&block) if block
      # Run optional resource hook
      resource.after_created
      # Store the resource to be inserted later
      (@subresources ||= []) << resource
      resource
    end

  end

  class Provider::Jenkins < LWRPBase
    def initialize(*args)
      super
      initialize_resource_defaults
    end

    def whyrun_supported?
      true
    end

    def action_install
      create_home_dir
      create_plugins_dir
      create_log_dir
      create_ssh_dir
      install_jenkins
      configure_service
    end

    def action_uninstall
      remove_home_dir
      remove_log_dir
      uninstall_jenkins
      remove_service
    end

    private

    def initialize_resource_defaults
      %w{home_dir_group plugins_dir_group ssh_dir_group plugins_dir_group log_dir_group log_dir_permissions}.each do |key|
        @new_resource.send(key, node['jenkins']['server'][key]) unless @new_resource.send(key)
      end
    end

    def create_home_dir
      r = Chef::Resource::Directory.new(@new_resource.path, @run_context)
      r.owner(@new_resource.user)
      r.group(@new_resource.home_dir_group)
      r.mode(@new_resource.dir_permissions)
      r.run_action(:create)
      updated_by_last_action(true) if r.updated?
      r
    end

    def create_plugins_dir
      r = Chef::Resource::Directory.new(::File.join(@new_resource.path, 'plugins'), @run_context)
      r.owner(@new_resource.user)
      r.group(@new_resource.plugins_dir_group)
      r.mode(@new_resource.dir_permissions)
      r.run_action(:create)
      updated_by_last_action(true) if r.updated?
      r
    end

    def create_log_dir
      r = Chef::Resource::Directory.new(@new_resource.log_dir, @run_context)
      r.owner(@new_resource.user)
      r.group(@new_resource.log_dir_group)
      r.mode(@new_resource.log_dir_permissions)
      r.run_action(:create)
      updated_by_last_action(true) if r.updated?
      r
    end

    def create_ssh_dir
      r = Chef::Resource::Directory.new(::File.join(@new_resource.path, '.ssh'), @run_context)
      r.owner(@new_resource.user)
      r.group(@new_resource.ssh_dir_group)
      r.mode(@new_resource.ssh_dir_permissions)
      r.run_action(:create)
      updated_by_last_action(true) if r.updated?
      r
    end

    def install_jenkins
      r = Chef::Resource::RemoteFile.new("#{self.new_resource.path}/jenkins-#{self.new_resource.version}.war", self.run_context)
      r.source(self.new_resource.war_url)
      r.owner(self.new_resource.user)
      r.group(self.new_resource.group)
      r.mode('644')
      r.run_action(:create)
      updated_by_last_action(true) if r.updated?
      r
    end

    def configure_service
    end

    def remove_home_dir
      r = Chef::Resource::Directory.new(@new_resource.path, @run_context)
      r.run_action(:remove)
      updated_by_last_action(true) if r.updated?
      r
    end

    def remove_log_dir
      r = Chef::Resource::Directory.new(@new_resource.log_dir, @run_context)
      r.run_action(:remove)
      updated_by_last_action(true) if r.updated?
      r
    end

    def uninstall_jenkins
      r = Chef::Resource::File.new("#{self.new_resource.path}/jenkins-#{self.new_resource.version}.war", self.run_context)
      r.run_action(:delete)
      updated_by_last_action(true) if r.updated?
      r
    end

    def remove_service
    end



    # Provider subclass to implement package-based installs
    class Package < Jenkins
      private
      def initialize_resource_defaults
        values = case node['platform_family']
        when 'debian'
          {
            log_dir_permissions: '755',
            home_dir_group: 'adm',
            log_dir_group: 'adm',
            ssh_dir_group: 'nogroup',
          }
        when 'rhel'
          {
            group: @new_resource.user,
            log_dir_permissions: '750',
            home_dir_group: @new_resource.user,
            log_dir_group: @new_resource.user,
            ssh_dir_group: @new_resource.user,
          }
        end
        return super unless values # As good as any other defaults I suppose
        values.each do |key|
          @new_resource.send(key, value) unless @new_resource.send(key)
        end
      end
    end

  end
end
