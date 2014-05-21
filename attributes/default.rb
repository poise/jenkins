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

# Default values for jenkins resource
# -----------------------------------
default['jenkins']['server']['update_url'] = 'https://updates.jenkins-ci.org/update-center.json'
default['jenkins']['server']['war_url'] = 'http://mirrors.jenkins-ci.org/war/%{version}/jenkins.war'
default['jenkins']['server']['plugin_url'] = 'http://mirrors.jenkins-ci.org/plugins/%{name}/%{version}/%{name}.hpi'
default['jenkins']['server']['log_dir'] = '/var/log/jenkins'
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
default['jenkins']['server']['slave_agent_port'] = :random
default['jenkins']['server']['nodes'] = {}

# Defaults values for jenkins_node resource
# -----------------------------------------
default['jenkins']['node']['home'] = '/home/jenkins'
default['jenkins']['node']['log_dir'] = '/var/log/jenkins'
default['jenkins']['node']['agent_type'] = 'jnlp'
case node['platform_family']
when 'mac_os_x'
  default['jenkins']['node']['home'] = '/Users/jenkins'
when 'windows'
  default['jenkins']['node']['home'] = 'C:/jenkins'
  default['jenkins']['node']['log_dir'] = 'C:/jenkins'
  default['jenkins']['node']['agent_type'] = 'windows'
  default['jenkins']['node']['service_user'] = 'LocalSystem'
  default['jenkins']['node']['service_user_password'] = nil
  # The native URL for this is http://repo.jenkins-ci.org/releases/com/sun/winsw/winsw/1.13/winsw-1.13-bin.exe but I want HTTPS
  default['jenkins']['node']['winsw_url'] = 'https://jenkinsci.artifactoryonline.com/jenkinsci/releases/com/sun/winsw/winsw/1.13/winsw-1.13-bin.exe'
end

default['jenkins']['node']['user'] = 'jenkins-node'
default['jenkins']['node']['group'] = 'jenkins-node'
default['jenkins']['node']['shell'] = '/bin/sh'
default['jenkins']['node']['server_url'] = nil
default['jenkins']['node']['name'] = node['fqdn']
default['jenkins']['node']['description'] =
  "#{node['platform']} #{node['platform_version']} " <<
  "[#{node['kernel']['os']} #{node['kernel']['release']} #{node['kernel']['machine']}] " <<
  "slave on #{node['hostname']}"
default['jenkins']['node']['labels'] = (node['tags'] || [])

default['jenkins']['node']['env'] = {}
default['jenkins']['node']['executors'] = 1
default['jenkins']['node']['in_demand_delay'] = 0
default['jenkins']['node']['idle_delay'] = 1

# Usage
# normal - Utilize this slave as much as possible
# exclusive - Leave this machine for tied jobs only
default['jenkins']['node']['mode'] = 'normal'

# Availability
# always - Keep this slave on-line as much as possible
# demand - Take this slave on-line when in demand and off-line when idle
default['jenkins']['node']['availability'] = 'always'

# SSH options
default['jenkins']['node']['ssh_host'] = node['fqdn']
default['jenkins']['node']['ssh_port'] = 22
default['jenkins']['node']['ssh_user'] = default['jenkins']['node']['user']
default['jenkins']['node']['ssh_pass'] = nil
default['jenkins']['node']['ssh_private_key'] = nil
default['jenkins']['node']['jvm_options'] = nil

# Default values for jenkins_cli resource
# ---------------------------------------
default['jenkins']['cli']['java_params'] = nil
default['jenkins']['cli']['key_file'] = nil

# Default values for jenkins_proxy resource
# ------------------------------------------
default['jenkins']['proxy']['listen_ports'] = [80]
default['jenkins']['proxy']['hostname'] = nil # node['fqdn']

default['jenkins']['proxy']['ssl_enabled'] = false
default['jenkins']['proxy']['ssl_redirect_http'] = true
default['jenkins']['proxy']['ssl_listen_ports'] = [443]
default['jenkins']['proxy']['ssl_path'] = nil # node['jenkins']['server']['home']}/ssl
default['jenkins']['proxy']['cert_path'] = nil # node['jenkins']['http_proxy']['ssl']['dir']}/jenkins.pem
default['jenkins']['proxy']['key_path'] = nil # node['jenkins']['http_proxy']['ssl']['dir']}/jenkins.key
default['jenkins']['proxy']['provider'] = nil # Auto-detects based on available cookbooks

# Values for the jenkins::server recipe
# -------------------------------------
default['jenkins']['server']['home'] = '/var/lib/jenkins'
default['jenkins']['server']['install_method'] = 'war'
default['jenkins']['enable_proxy'] = true
