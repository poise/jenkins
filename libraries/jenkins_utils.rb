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


module JenkinsUtils
  extend self

  private
  def update_center(node=nil)
    node ||= self.node if self.respond_to?(:node)
    @@update_center ||= begin
      data = open(node['jenkins']['server']['update_url']).read.split("\n")
      # Remove the first and last lines since those are actually Javascript code used for JSONP
      data.delete_at(0)
      data.delete_at(-1)
      Chef::JSONCompat.from_json(data.join("\n"), create_additions: false)
    end
  end
end
