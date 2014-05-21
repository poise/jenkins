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
* `node['jenkins']['node']['jvm_options']` – Extra JVM command options.
* `node['jenkins']['node']['mode']` – Job distribution mode. One of: `normal`, `exclusive`. *(default: normal)*

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
