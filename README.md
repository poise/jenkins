Jenkins Cookbook
================

This cookbook installs and configures the [Jenkins](https://jenkins-ci.org/)
continuous integration server.

Quick Start
-----------

To install a basic Jenkins server, the following to the node's run list:

* `recipe[nginx]`
* `recipe[jenkins]`

This will install the latest version of Jenkins in to `/var/lib/jenkins` and

Requirements
------------

### Cookbooks

The following cookbooks are required:

* apt
* java
* partial_search
* poise
* runit
* yum

One of the follow is required if using the TLS proxy feature ()

### OS

The following platforms are supported and tested:

* Ubuntu 12.04

### Chef

This cookbook requires Chef 11 or higher.

Attributes
----------

### Server attributes

* `node['jenkins']['server']['update_url']` – URL to download the update center JSON. *(default: https://updates.jenkins-ci.org/update-center.json)*
* `node['jenkins']['server']['war_url']` – URL template to download the Jenkins WAR. *(default: http://mirrors.jenkins-ci.org/war/%{version}/jenkins.war)*
* `node['jenkins']['server']['plugin_url']` – URL template to download Jenkins plugins. *(default: http://mirrors.jenkins-ci.org/plugins/%{name}/%{version}/%{name}.hpi)*
* `node['jenkins']['server']['home']` – Jenkins data directory. *(default: /var/lib/jenkins)*
* `node['jenkins']['server']['log_dir']` – Jenkins log directory. *(default: /var/log/jenkins)*
* `node['jenkins']['server']['user']` – User to run Jenkins as. *(default: jenkins)*
* `node['jenkins']['server']['group']` – Group to run Jenkins as. *(default: node['jenkins']['server']['user'])*
* `node['jenkins']['server']['home_dir_group']` – Group for Jenkins data directory. *(default: node['jenkins']['server']['user'])*
* `node['jenkins']['server']['plugins_dir_group']` – Group for plugins directory. *(default: node['jenkins']['server']['user'])*
* `node['jenkins']['server']['ssh_dir_group']` – Group for SSH configuration. *(default: node['jenkins']['server']['user'])*
* `node['jenkins']['server']['log_dir_group']` – Group for log directory. *(default: node['jenkins']['server']['user'])*
* `node['jenkins']['server']['dir_permissions']` – Mode for Jenkins data directory. *(default: 755)*
* `node['jenkins']['server']['ssh_dir_permissions']` – Mode for SSH configuration. *(default: 700)*
* `node['jenkins']['server']['log_dir_permissions']` – Mode for log directory. *(default: 755)*
* `node['jenkins']['server']['port']` – HTTP port for Jenkins. *(default: 8080)*
* `node['jenkins']['server']['host']` – Hostname for Jenkins URLs. *(default: node['fqdn'])*
* `node['jenkins']['server']['url']` – URL for the Jenkins server. *(default: http://#{host}:#{port})*
* `node['jenkins']['server']['slave_agent_port']` – Port for JNLP builder nodes. `:random` will set it randomly on every restart. *(default: :random)*
* `node['jenkins']['server']['nodes']` Jenkins builder node data. See [chef-solo usage section]() for details.

### Builder node attributes

* `node['jenkins']['node']['home']` – Jenkins node data directory. *(default: /home/jenkins, OSX: /Users/jenkins, Win: C:\Jenkins)*
* `node['jenkins']['node']['log_dir']` – Jenkins node log directory. *(default: /var/log/jenkins, Win: C:\Jenkins)*
* `node['jenkins']['node']['agent_type']` – Builder node type. One of: `jnlp`, `ssh`, `windows`. *(default: jnlp, Win: windows)* **TODO: NOT ACTUALLY USED**
* `node['jenkins']['node']['user']` – User to run Jenkins node as. *(default: jenkins-node)*
* `node['jenkins']['node']['group']` – Group to run Jenkins node as. *(default: jenkins-node)*
* `node['jenkins']['node']['server_url']` – URL for JNLP builder to connect to. Not used in SSH mode.
* `node['jenkins']['node']['name']` – Builder node name. *(default: node['fqdn'])*
* `node['jenkins']['node']['description']` – Builder node description. *(default: long and complicated)*
* `node['jenkins']['node']['labels']` – Builder node labels. *(default: node['tags'])*
* `node['jenkins']['node']['executors']` – Number of execution slots for the node. *(default: 1)*
* `node['jenkins']['node']['availability']` – Node availability mode. One of: `always`, `demand`. *(default: always)*
* `node['jenkins']['node']['in_demand_delay']` – Time to wait before activating node. Only used in `demand` availability mode. *(default: 0)*
* `node['jenkins']['node']['idle_delay']` – Time to allow the node to be idea before deactivating. Only used in `demand` availability mode. *(default: 1)*
* `node['jenkins']['node']['mode']` – Job distribution mode. One of: `normal`, `exclusive`. *(default: normal)*
* `node['jenkins']['node']['jvm_options']` – Extra JVM command-line options.

#### SSH node attributes

These only apply if using the `ssh` builder type.

* `node['jenkins']['node']['ssh_host']` – Hostname to SSH to. *(default: node['fqdn'])*
* `node['jenkins']['node']['ssh_port']` – Port to SSH to. *(default: 22)*
* `node['jenkins']['node']['ssh_user']` – Username to SSH as. *(default: node['jenkins']['node']['user'])*
* `node['jenkins']['node']['ssh_pass']` – Password to SSH with. Mutually exclusive with `ssh_private_key`.
* `node['jenkins']['node']['ssh_private_key']` – Private key to SSH with. Mutually exclusive with `ssh_pass`.
* `node['jenkins']['node']['shell']` – Shell for the builder user. *(default: /bin/sh)*

#### Windows node attributes

These only apply if using the `windows` builder type.

* `node['jenkins']['node']['winsw_url']` – Download URL for the winsw service helper program. *(default: https://jenkinsci.artifactoryonline.com/jenkinsci/releases/com/sun/winsw/winsw/1.13/winsw-1.13-bin.exe)*

### CLI attributes

* `node['jenkins']['cli']['key_file']` – SSH private key for jenkins-cli.
* `node['jenkins']['cli']['jvm_options']` – Extra JVM command-line options.

### Proxy attributes

* `node['jenkins']['proxy']['listen_ports']` – HTTP listen ports. *(default: 80)*
* `node['jenkins']['proxy']['hostname']` – Hostname for the proxy vhost. *(default: node['fqdn'])*
* `node['jenkins']['proxy']['ssl_enabled']` – Enable HTTPS proxy. *(default: false)*
* `node['jenkins']['proxy']['ssl_redirect_http']` – Redirect HTTP requests to HTTPS. Only applies if HTTPS is enabled. *(default: true)*
* `node['jenkins']['proxy']['ssl_listen_ports']` – HTTPS listen ports. *(default: 443)*
* `node['jenkins']['proxy']['ssl_path']` – Base path for TLS data. *(default: node['jenkins']['server']['home']/ssl)*
* `node['jenkins']['proxy']['cert_path']` – Path to TLS certificate. *(default: node['jenkins']['proxy']['ssl_path']}/jenkins.pem)*
* `node['jenkins']['proxy']['key_path']` – Path to TLS key. *(default: node['jenkins']['proxy']['ssl_path']}/jenkins.key)*
* `node['jenkins']['proxy']['provider']` – Proxy implementation provider. One of: `apache2`, `nginx`. *(default: auto-detect)*

Recipes
-------

### default

The default recipe (`recipe[jenkins]`) installs a Jenkins server and optionally
an HTTPS proxy server.

Resources
---------

### jenkins

The `jenkins` resource installs and configures a Jenkins server using the
default WAR distribution.

```ruby
jenkins '/srv/jenkins' do
  user 'ci'
  url 'https://ci.example.com/'
end
```

*TODO: Fill this in. In the interim, see the Attributes section.*

### jenkins_config

The `jenkins_config` resource adds a section of configuration to the Jenkins
config.xml file. It is a subresource of `jenkins`.

```ruby
jenkins_config 'name' do
  source 'myconfig.xml.erb'
end
```

* `config_name` – Name of the snippet. *(name_attribute)*
* `''` – Configuration template. *([template](https://github.com/poise/poise#template-content), required)*

### jenkins_job

The `jenkins_job` resource creates a Jenkins build job. It is a subresource of
`jenkins`.

```ruby
jenkins_job 'name' do
  source 'myjob.xml.erb'
end
```

* `job_name` – Name of the job. *(name_attribute)*
* `''` – Job template. *([template](https://github.com/poise/poise#template-content), required)*

### jenkins_plugin

The `jenkins_plugin` resource installs and enables a Jenkins plugin. It is a
subresource of `jenkins`.

Unfortunately due to issues with the Jenkins plugin distribution system, it is
not possible to safely install anything but the latest version of a plugin. As
such, this cookbook does not allow setting a version on a plugin.

```ruby
jenkins_plugin 'git'
```

* `plugin_name` – Name of the plugin. *(name_attribute)*
* `url` – URL template for the download URL. *(default: node['jenkins']['server']['plugin_url'])*

### jenkins_view

The `jenkins_view` resource creates a Jenkins view. These are the tabs of jobs
on the main homepage. It is a subresource of `jenkins`.

```ruby
jenkins_view 'name' do
  jobs %w{myjob otherjob}
end
```

* `view_name` – Name of the view. *(name_attribute)*
* `''` – View template. *([template](https://github.com/poise/poise#template-content), default_source: view.xml.erb)*
* `jobs` – Array of jobs to include in the view.

### jenkins_node

The `jenkins_node` resource installs and configures a Jenkins builder node.
Three types are available: `jnlp`, `ssh`, and `windows`. It is optionally a
subresource of `jenkins`.

**WARNING: The `windows` type is incomplete and the `ssh` type is untested.***

```ruby
jenkins_node 'name' do
  path '/srv/jenkins'
  user 'ci'
end
```

*TODO: Fill this in. In the interim, see the Attributes section.*

### jenkins_execute

The `jenkins_execute` resource runs a command and passes the output to a block.
It is optionally a subresource of `jenkins`.

It is rarely used, please consult the source code for more information.

### jenkins_cli

The `jenkins_cli` resource runs a command using the `jenkins-cli.jar` command
line tool.

```ruby
jenkins_cli 'disable-job myjob' do
  key_file '/srv/ci/cli.pem'
end
```

* `command` – Command to run. *(name_attribute)*
* `timeout` – Command timeout. *(default: no timeout)*
* `block` – An optional ruby code block that gets passed the command output.
* `url` – Jenkins server URL. *(default: parent.url)*
* `path` – Path to Jenkins data directory. *(default: parent.path)*
* `java_home` – Path to Java home. *(default: node['jenkins']['java_home'] or node['java']['java_home'])*
* `jvm_options` – Extra Java command line options. *(default: node['jenkins']['cli']['jvm_options'])*
* `key_file` – SSH private key for authentication. *(default: node['jenkins']['cli']['key_file'])*

License
-------

Copyright 2010, VMWare, Inc.

Copyright 2012, Opscode, Inc.

Copyright 2013, Youscribe.

Copyright 2013-2014, Balanced, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

