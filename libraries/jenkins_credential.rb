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

require 'digest/sha1'

require File.expand_path('../jenkins', __FILE__)

class Chef
  class Resource::JenkinsCredential < Resource::LWRPBase
    include Poise
    poise_subresource(Jenkins)
    self.resource_name = :jenkins_credential
    default_action(:create)
    actions(:remove)

    attribute(:uuid, kind_of: String, default: lazy { _uuid })
    attribute(:username, kind_of: String, default: lazy { name.split('::').last })
    attribute(:passphrase, kind_of: String)
    attribute(:key, kind_of: String, required: true)
    attribute(:description, kind_of: String)

    def path
      ::File.join(parent.credentials_d_path, "#{name}.xml")
    end

    def after_created
      super
      notifies(:rebuild_config, parent)
    end

    private

    # Derive something that looks like a UUID from the name
    def _uuid
      hash = Digest::SHA1.hexdigest(name)
      [20, 12, 16, 8].inject(hash[0..31]) {|memo, n| memo.insert(n, '-')}
    end
  end

  class Provider::JenkinsCredential < Provider::LWRPBase
    include Poise

    def action_create
      notifying_block do
        create_template
      end
    end

    def action_remove
      notifying_block do
        remove_template
      end
    end

    private

    def create_template
      template new_resource.path do
        source 'credential.xml.erb'
        cookbook 'jenkins'
        owner new_resource.parent.user
        group new_resource.parent.group
        mode '600'
        variables new_resource: new_resource
      end
    end

    def remove_template
      r = create_template
      r.action(:delete)
      r
    end

  end
end
