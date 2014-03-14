#
# Author:: Noah Kantrowitz <noah@coderanger.net>
#
# Copyright 2013-2014, Balanced, Inc.
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

require 'serverspec'
include Serverspec::Helper::Exec
include Serverspec::Helper::DetectOS

describe port(8080) do
  it { should be_listening }
end

describe file('/home/jenkins') do
  it { should be_a_directory }
end

describe file('/var/lib/jenkins/config.xml') do
  its(:content) { should include('<name>teapot</name>') }
  its(:content) { should include('<label>iama teapot</label>') }
  its(:content) { should include('<remoteFS>/home/jenkins</remoteFS>') }
end

describe file('/etc/service/jenkins-slave-teapot') do
  it { should be_a_directory }
end

describe process('java -jar /home/jenkins/slave.jar') do
  it { should be_running }
end
