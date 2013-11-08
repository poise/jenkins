#
# Author:: Noah Kantrowitz <noah@coderanger.net>
#
# Copyright 2013, Opscode, Inc.
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

require 'digest/sha1'

require File.expand_path('../jenkins', __FILE__)
require File.expand_path('../jenkins_utils', __FILE__)

class Chef
  class Resource::JenkinsPlugin < Resource::LWRPBase
    include Poise
    include Poise::Resource::SubResource
    include JenkinsUtils
    self.resource_name = :jenkins_plugin
    default_action(:install)
    actions(:remove)
    parent_type(Jenkins)

    attribute(:plugin_name, kind_of: String, default: lazy { name.split('::').last })
    # Unfortunately I cannot allow installing anything but the latest version
    # because the plugin metadata only provides the latest, and so for anything
    # else I can't check dependencies or SHA hashes.
    attribute(:url, kind_of: String, default: lazy { node['jenkins']['server']['plugin_url'] })


    def version

    end

    def after_created
      super
      plugin_data = update_center['plugins'][plugin_name]
      unless plugin_data
        similar = update_center['plugins'].each_key.select {|p| levenshtein_distance(name, p) <= 2}
        raise "Unknown plugin #{plugin_name}." + (similar.empty? ? '' : " Maybe you meant one of: #{similar.join(', ')}")
      end
      plugin_data['dependencies'].each do |dep_data|
        next if dep_data['optional']
        begin
          # Try to find the dependent plugin
          run_context.resource_collection.find("#{resource_name}[#{dep_data['name']}]")
        rescue Chef::Exceptions::ResourceNotFound
          # Didn't find it, synthesize a resource to pretends to come from the same place
          dep = self.class.new(dep_data['name'], run_context)
          dep.source_line = source_line
          dep.load_prior_resource
          dep.cookbook_name = cookbook_name
          dep.recipe_name = recipe_name
          dep.params = params
          dep.enclosing_provider = enclosing_provider
          dep.parent(parent)
          dep.after_created
          run_context.resource_collection.insert(dep)
        end
      end
    end

    private
    # From http://rosettacode.org/wiki/Levenshtein_distance#Ruby
    # Under the GNU Free Documentation License 1.2.
    def levenshtein_distance(s, t)
      m = s.length
      n = t.length
      return m if n == 0
      return n if m == 0
      d = Array.new(m+1) {Array.new(n+1)}

      (0..m).each {|i| d[i][0] = i}
      (0..n).each {|j| d[0][j] = j}
      (1..n).each do |j|
        (1..m).each do |i|
          d[i][j] = if s[i-1] == t[j-1]  # adjust index into string
                      d[i-1][j-1]       # no operation required
                    else
                      [ d[i-1][j]+1,    # deletion
                        d[i][j-1]+1,    # insertion
                        d[i-1][j-1]+1,  # substitution
                      ].min
                    end
        end
      end
      d[m][n]
    end

  end

  class Provider::JenkinsPlugin < Provider::LWRPBase
    include Poise
    include JenkinsUtils
    def whyrun_supported?
      true
    end

    def action_install
      Chef::Log.debug "#{new_resource}: current version=#{current_version}, requested version=#{latest_version}"

      # TODO: If @new_resource.version == 'latest', lookup the new version
      # and assign it to @new_resource.version

      if current_version && current_version != latest_version
        converge_by("Upgrading #{new_resource} from #{current_version} to #{latest_version}") do
          do_upgrade_plugin
        end
      elsif plugin_exists?
        Chef::Log.debug "#{new_resource} already exists"
      else
        converge_by("Installing #{new_resource} version #{latest_version}") do
          do_install_plugin
        end
      end
    end

    def action_remove
      if plugin_exists?
        converge_by("remove #{@new_resource}") do
          do_remove_plugin
        end
      else
        Chef::Log.debug "#{@new_resource} doesn't exist"
      end
    end

    def file_matches?
      Digest::SHA1.base64digest(IO.read(plugin_file_path)) == update_center['plugins'][new_resource.plugin_name]['sha1']
    rescue Errno::ENOENT
      false
    end

  private

    def latest_version
      @latest_version ||= update_center['plugins'][new_resource.plugin_name]['version']
    end

    def current_version
      @current_version ||= begin
        version = nil
        manifest_file = ::File.join(plugins_dir, new_resource.plugin_name, 'META-INF', 'MANIFEST.MF')
        if ::File.exist?(manifest_file)
          manifest = IO.read(manifest_file)
          version = manifest.match(/^Plugin-Version:\s*(.+)$/)[1].strip
        end
        version
      end
    end

    def plugin_exists?
      ::File.exists?(plugin_file_path)
    end

    def plugin_dir_path
      ::File.join(plugins_dir, new_resource.plugin_name)
    end

    def plugin_file_path
      ::File.join(plugins_dir, "#{new_resource.plugin_name}.jpi")
    end

    def plugins_dir
      ::File.join(new_resource.parent.path, 'plugins')
    end

    def do_install_plugin
      self_ = self
      plugin_url = new_resource.url  % {name: new_resource.plugin_name, version: latest_version}
      notifying_block do
        # Plugins installed from the Jenkins Update Center are written to disk with
        # the `*.jpi` extension. Although plugins downloaded from the Jenkins Mirror
        # have an `*.hpi` extension we will save the plugins with a `*.jpi` extension
        # to match Update Center's behavior.
        rf = remote_file plugin_file_path do
          source plugin_url
          owner new_resource.parent.user
          group new_resource.parent.plugins_dir_group
          backup false
          action :create
          notifies :restart, new_resource.parent
          notifies :create, 'ruby_block[check_sha1]', :immediately
          not_if { self_.file_matches? }
        end

        ruby_block 'check_sha1' do
          action :nothing
          block do
            unless self_.file_matches?
              # To be safe, remove the file so that it isn't accidentally loaded
              rf.run_action(:delete)
              raise "File integrity check failed, possible security issue"
            end
          end
        end

        file "#{plugin_file_path}.pinned" do
          action :create_if_missing
          owner new_resource.parent.user
          group new_resource.parent.plugins_dir_group
        end
      end
    end

    def do_upgrade_plugin
      do_install_plugin
    end

    def do_remove_plugin
      notifying_block do
        file plugin_file_path do
          action :delete
          backup false
          notifies :restart, new_resource.parent
        end

        directory plugin_dir_path do
          action :delete
          recursive true
          notifies :restart, new_resource.parent
        end
      end
    end

  end
end
