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

require File.expand_path('../jenkins_execute', __FILE__)

class Chef
  class Resource::JenkinsCli < Resource::JenkinsExecute
    attribute(:url, kind_of: String, default: lazy { parent && parent.url })
    attribute(:path, kind_of: String, default: lazy { parent && parent.path })
    attribute(:java_home, kind_of: String, default: lazy { node['jenkins']['java_home'] || (node['java'] && node['java']['java_home'])})
    attribute(:jvm_options, kind_of: String, default: lazy { node['jenkins']['cli']['jvm_options'] })
    attribute(:key_file, kind_of: String, default: lazy { node['jenkins']['cli']['key_file'] })

    def after_created
      super
      # TODO: Replace these with required:true in the attribute definition.
      raise "URL is require" unless url
      raise "Path is required" unless path
    end

    # Create an alias
    def cwd
      path
    end

    def cli_jar
      ::File.join(path, 'jenkins-cli.jar')
    end

    # Compute the command to run
    def cli_command
      @cli_command ||= begin
        cmd = if java_home
          "\"#{::File.join(java_home, 'bin', 'java')}\""
        else
          'java' # Fallback and hope it exists
        end
        cmd << " #{jvm_options}" if jvm_options
        cmd << " -jar #{cli_jar}"
        cmd << " -i #{key_file}" if key_file
        cmd << " -s #{url} #{command}"
        cmd
      end
    end
  end

  class Provider::JenkinsCli < Provider::JenkinsExecute
    def action_run
      converge_by("run jenkins-cli command: #{new_resource.cli_command}") do
        notifying_block do
          create_directory
          create_cli_jar
        end
        run_command(new_resource.cli_command, &new_resource.block)
        new_resource.updated_by_last_action(true) # Always updated
      end
    end

    private

    def create_directory
      directory new_resource.path
    end

    def create_cli_jar
      remote_file new_resource.cli_jar do
        source "#{new_resource.url}/jnlpJars/jenkins-cli.jar"
        not_if { ::File.exists?(new_resource.cli_jar) }
      end
    end

  end
end
