#
# Author:: Doug MacEachern <dougm@vmware.com>
# Author:: Fletcher Nichol <fnichol@nichol.ca>
# Author:: Seth Chisamore <schisamo@opscode.com>
# Author:: Noah Kantrowitz <noah@coderanger.net>
#
# Copyright 2010, VMware, Inc.
# Copyright 2012, Opscode, Inc.
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
  class Resource::JenkinsJob < Resource
    include Poise(Jenkins)
    actions(:update, :create, :delete, :build, :disable, :enable)

    attribute(:job_name, kind_of: String, default: lazy { name.split('::').last })
    attribute('', template: true, required: true)

    def path
      ::File.join(parent.jobs_path, job_name, 'config.xml')
    end

    def after_created
      super
      notifies(:restart, self.parent)
    end
  end

  class Provider::JenkinsJob < Provider
    include Poise

    def action_update
      notifying_block do
        create_directory
        write_config
      end
    end

    def action_delete
      notifying_block do
        delete_directory
      end
    end

    private

    def create_directory
      directory ::File.join(new_resource.parent.jobs_path, new_resource.job_name) do
        owner new_resource.parent.user
        group new_resource.parent.group
        mode new_resource.parent.dir_permissions
      end
    end

    def write_config
      file new_resource.path do
        content new_resource.content
        owner new_resource.parent.user
        group new_resource.parent.group
        mode '600'
      end
    end

    def delete_directory
      r = create_directory
      r.action(:delete)
      r
    end
  end
end

