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
  class Resource::JenkinsView < Resource
    include Poise(Jenkins)
    actions(:enable)

    attribute(:view_name, kind_of: String, default: lazy { name.split('::').last })
    attribute('', template: true, default_source: 'view.xml.erb')
    attribute(:jobs, kind_of: Array, default: [])
  end

  class Provider::JenkinsView < Provider
    include Poise

    def action_enable
      # This space left intentionally blank
    end
  end
end
