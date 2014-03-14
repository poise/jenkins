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
  class Resource::JenkinsCredential < Resource
    include Poise(Jenkins)
    actions(:enable)

    attribute('', template: true, default_source: 'credential.xml.erb')
    attribute(:uuid, kind_of: String, default: lazy { _uuid })
    attribute(:username, kind_of: String, default: lazy { name.split('::').last })
    attribute(:passphrase, kind_of: String)
    attribute(:key, kind_of: String, required: true)
    attribute(:description, kind_of: String)

    private

    # Derive something that looks like a UUID from the name
    def _uuid
      hash = Digest::SHA1.hexdigest(name)
      [20, 12, 16, 8].inject(hash[0..31]) {|memo, n| memo.insert(n, '-')}
    end
  end

  class Provider::JenkinsCredential < Provider
    include Poise

    def action_enable
      # Force the configs to regenerate
      new_resource.parent.run_action(:configure)
    end
  end
end
