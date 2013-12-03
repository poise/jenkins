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

require 'chef/mixin/shell_out'

require File.expand_path('../jenkins', __FILE__)

class Chef
  class Resource::JenkinsExecute < Resource
    include Poise(parent: Jenkins, parent_optional: true)
    include Chef::Mixin::ShellOut
    actions :run

    attribute(:command, kind_of: String, name_attribute: true)
    attribute(:cwd, kind_of: String)
    attribute(:timeout, kind_of: Integer)

    def block(&block)
      set_or_return(:block, block, kind_of: Proc)
    end
  end

  class Provider::JenkinsExecute < Provider
    include Poise

    def action_run
      run_command(new_resource.command, &new_resource.block)
      new_resource.updated_by_last_action(true)
    end

    private

    def run_command(command, &block)
      args = {}
      args[:timeout] = new_resource.timeout if new_resource.timeout
      args[:cwd] = new_resource.cwd if new_resource.cwd
      cmd = shell_out!(command, args)
      block.call(cmd.stdout) if block
    end
  end
end
