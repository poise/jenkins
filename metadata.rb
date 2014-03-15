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

name 'jenkins'
# Lead with a 99 to override the similarly-named cookbook from the community site
version '99.1.19'

maintainer 'Noah Kantrowitz'
maintainer_email 'noah@coderanger.net'
license 'Apache 2.0'
description 'Installs and configures Jenkins CI server & slaves'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))

depends 'partial_search'
depends 'poise', '~> 1.0.2'
depends 'java'
depends 'runit', '>= 1.0.0'
depends 'apt'
depends 'yum'

recipe 'server', 'Installs Jenkins server'
