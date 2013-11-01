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

# Default values for jenkins resource parameters
default['jenkins']['server']['update_url'] = 'https://updates.jenkins-ci.org/update-center.json'
default['jenkins']['server']['war_url'] = 'http://mirrors.jenkins-ci.org/war/%{version}/jenkins.war'
default['jenkins']['server']['plugin_url'] = 'http://mirrors.jenkins-ci.org/plugins/%{name}/%{version}/%{name}.hpi'
default['jenkins']['server']['log_dir'] = '/var/log/jenkins'
default['jenkins']['server']['service_name'] = 'jenkins'
default['jenkins']['server']['user'] = 'jenkins'
default['jenkins']['server']['group'] = default['jenkins']['server']['user']
default['jenkins']['server']['home_dir_group'] = default['jenkins']['server']['user']
default['jenkins']['server']['plugins_dir_group'] = default['jenkins']['server']['user']
default['jenkins']['server']['ssh_dir_group'] = default['jenkins']['server']['user']
default['jenkins']['server']['log_dir_group'] = default['jenkins']['server']['user']
default['jenkins']['server']['dir_permissions'] = '755'
default['jenkins']['server']['ssh_dir_permissions'] = '700'
default['jenkins']['server']['log_dir_permissions'] = '755'
default['jenkins']['server']['port'] = 8080
default['jenkins']['server']['host'] = node['fqdn']
default['jenkins']['server']['url'] = nil

# Values for the jenkins::server recipe
default['jenkins']['server']['home'] = '/var/lib/jenkins'
default['jenkins']['server']['install_method'] = 'war'
