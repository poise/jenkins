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

require File.expand_path('../jenkins', __FILE__)

class Chef
  class Resource::JenkinsProxy < Resource
    include Poise(Jenkins)
    actions(:install)

    attribute('', template: true)
    attribute(:listen_ports, kind_of: Array, default: lazy { node['jenkins']['proxy']['listen_ports'] })
    attribute(:hostname, kind_of: String, default: lazy { node['jenkins']['proxy']['hostname'] || node['fqdn'] })
    attribute(:ssl_enabled, equal_to: [true, false], default: lazy { node['jenkins']['proxy']['ssl_enabled'] })
    attribute(:ssl_redirect_http, equal_to: [true, false], default: lazy { node['jenkins']['proxy']['ssl_redirect_http'] })
    attribute(:ssl_listen_ports, kind_of: Array, default: lazy { node['jenkins']['proxy']['ssl_listen_ports'] })
    attribute(:ssl_path, kind_of: String, default: lazy { ::File.join(parent.path, 'ssl') })
    attribute(:cert_path, kind_of: String, default: lazy { ::File.join(ssl_path, 'jenkins.pem') })
    attribute(:key_path, kind_of: String, default: lazy { ::File.join(ssl_path, 'jenkins.key') })

    def provider(arg=nil)
      if arg.kind_of?(String) || arg.kind_of?(Symbol)
        class_name = Mixin::ConvertToClassName.convert_to_class_name(arg.to_s)
        arg = Provider::JenkinsProxy.const_get(class_name) if Provider::JenkinsProxy.const_defined?(class_name)
      end
      super(arg)
    end

    def provider_for_action(*args)
      unless provider
        if node['jenkins']['proxy']['provider']
          provider(node['jenkins']['proxy']['provider'].to_sym)
        elsif run_context.cookbook_collection['apache2']
          provider(:apache)
        elsif run_context.cookbook_collection['nginx']
          provider(:nginx)
        else
          raise 'Unable to autodetect proxy provider, please specify one'
        end
      end
      super
    end

    def after_created
      super
      raise "#{self}: Only one of source or content can be specified" if source && content
    end
  end

  class Provider::JenkinsProxy < Provider
    include Poise

    def action_install
      converge_by("install a proxy server named #{Array(new_resource.hostname).join(', ')} for the Jenkins server at port #{new_resource.parent.port}") do
        notifying_block do
          install_server
          configure_server
          enable_vhost
        end
      end
    end

    private

    def install_server
      raise NotImplementedError
    end

    def config_path
      raise NotImplementedError
    end

    def server_resource
      raise NotImplementedError
    end

    def configure_server
      # Only set the default source if nothing is currently set
      source(default_source) if !source && !content(nil, true)
      file config_path do
        content new_resource.content
        owner 'root'
        group 'root'
        mode '600'
      end
    end

    def enable_vhost
      raise NotImplementedError
    end
  end

  class Provider::JenkinsProxy::Nginx < Provider::JenkinsProxy
    def install_server
      include_recipe 'nginx'
    end

    def config_path
      ::File.join(node['nginx']['dir'], 'sites-available','jenkins.conf')
    end

    def default_source
      'proxy_nginx.conf.erb'
    end

    def server_resource
      'service[nginx]'
    end

    def enable_vhost
      nginx_site 'jenkins.conf' do
        enable true
      end
    end
  end

  class Provider::JenkinsProxy::Apache < Provider::JenkinsProxy
    def install_server
      include_recipe 'apache2'
      include_recipe 'apache2::mod_ssl' if new_resource.ssl_enabled

      apache_module 'proxy'
      apache_module 'proxy_http'
      apache_module 'vhost_alias'
    end

    def config_path
      ::File.join(node['apache']['dir'], 'sites-available','jenkins.conf')
    end

    def default_source
      'proxy_apache.conf.erb'
    end

    def server_resource
      'service[apache2]'
    end

    def enable_vhost
      apache_site 'jenkins.conf' do
        enable true
      end
    end
  end
end
