#
# Author:: Noah Kantrowitz <noah@coderanger.net>
#
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
  class Resource::JenkinsConfig < Resource
    include Poise(Jenkins)
    actions(:enable, :disable)

    attribute(:config_name, kind_of: String, default: lazy { name.split('::').last })
    attribute('', template: true, required: true)

    def path
      ::File.join(parent.config_d_path, "#{config_name}.xml")
    end

    def after_created
      super
      notifies(:rebuild_config, parent)
    end
  end

  class Provider::JenkinsConfig < Provider
    include Poise

    def action_enable
      notifying_block do
        write_config
      end
    end

    def action_disable
      notifying_block do
        delete_config
      end
    end

    private

    def write_config
      file new_resource.path do
        content new_resource.content
        owner new_resource.parent.user
        group new_resource.parent.group
        mode '600'
      end
    end

    def delete_config
      file new_resource.path do
        action :delete
      end
    end
  end
end
