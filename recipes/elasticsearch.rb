#
# Cookbook Name:: cluster
# Recipe:: elasticsearch
#
# Author: Mevan Samaratunga
# Email: mevansam@gmail.com
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

cluster_name = node["cluster_name"]
unless cluster_name.nil?
    # Setup a multi-node cluster of nodes having the same 'cluster_name'
    search_query = "cluster_name:#{cluster_name} AND chef_environment:#{node.chef_environment}"
    Chef::Log.info("Searching for cluster nodes matching: #{search_query}")
    
    node.override["elasticsearch"]["discovery"]["search_query"] = search_query
    node.override["elasticsearch"]["discovery"]["node_attribute"] = nil

    include_recipe "elasticsearch::search_discovery"
end

if !node["elasticsearch"]["certificate_databag_item"].nil? &&
    !node["elasticsearch"]["certificate_databag_item"].empty?

    encryption_key = ::SysUtils::get_encryption_secret(node)
    certificates = Chef::EncryptedDataBagItem.load( "certificates-#{node.chef_environment}", 
        node["elasticsearch"]["certificate_databag_item"], encryption_key )

    nginx_config_path = node["nginx"]["dir"] 
    directory nginx_config_path do
        recursive true
    end

    cacert_path = "#{nginx_config_path}/cacert.pem"
    cert_path = "#{nginx_config_path}/cert.pem"
    key_path = "#{nginx_config_path}/key.pem"

    file cacert_path do
        owner "root"
        group "root"
        mode "0644"
        content certificates["cacert"]
    end
    
    file cert_path do
        owner "root"
        group "root"
        mode "0644"
        content certificates["cert"]
    end
    
    file key_path do
        owner "root"
        group "root"
        mode "0644"
        content certificates["key"]
    end

    node.override["elasticsearch"]["nginx"]["cert_file"] = cert_path
    node.override["elasticsearch"]["nginx"]["key_file"] = key_path
end

include_recipe "elasticsearch::default"
include_recipe "elasticsearch::proxy"
