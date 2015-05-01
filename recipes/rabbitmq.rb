#
# Cookbook Name:: cluster
# Recipe:: rabbitmq
#
# Author: Mevan Samaratunga
# Email: mevansam@gmail.com
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

encryption_key = ::SysUtils::get_encryption_secret(node)
rabbit_passwords = Chef::EncryptedDataBagItem.load("passwords-#{node.chef_environment}", "rabbit", encryption_key)

default_user = rabbit_passwords["default_user"]
default_password = rabbit_passwords["default_password"]

node.override['rabbitmq']['default_user'] = default_user
node.override['rabbitmq']['default_pass'] = default_password

node.override['rabbitmq']['erlang_cookie'] = rabbit_passwords["erlang_cookie"]

if node['rabbitmq']['ssl']
    !node["rabbitmq"]["certificate_databag_item"].nil? &&
    !node["rabbitmq"]["certificate_databag_item"].empty?

	certificates = Chef::EncryptedDataBagItem.load("certificates-#{node.chef_environment}", node["rabbitmq"]["certificate_databag_item"], encryption_key)

	rabbit_config_path = node["rabbitmq"]['config_root']
	directory rabbit_config_path

	cacert_path = "#{rabbit_config_path}/cacert.pem"
	cert_path = "#{rabbit_config_path}/cert.pem"
	key_path = "#{rabbit_config_path}/key.pem"

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

	node.override['rabbitmq']['ssl_cacert'] = cacert_path
	node.override['rabbitmq']['ssl_cert'] = cert_path
	node.override['rabbitmq']['ssl_key'] = key_path
end

# Determine which nodes are in rabbitmq cluster
cluster_name = node["cluster_name"]
unless cluster_name.nil?

    cluster_disk_nodes = []

    search_query = "cluster_name:#{cluster_name} AND chef_environment:#{node.chef_environment}"
    Chef::Log.info("Searching for cluster nodes matching: #{search_query}")

    search(:node, search_query).each do |rabbitmq_node|

        rabbitmq_cluster_node = "rabbit@#{rabbitmq_node['hostname']}"
        Chef::Log.info("Adding node '#{rabbitmq_node.name}' as rabbitmq cluster node '#{rabbitmq_cluster_node}'.")

        cluster_disk_nodes << rabbitmq_cluster_node

        unless rabbitmq_node["ipaddress"]==node["ipaddress"]
            hostsfile_entry rabbitmq_node["ipaddress"] do
                hostname rabbitmq_node['hostname']
            end
        end
    end
    cluster_disk_nodes.sort!

    node.override['rabbitmq']['cluster'] = true
    node.override['rabbitmq']['cluster_disk_nodes'] = cluster_disk_nodes
end

include_recipe 'rabbitmq::default'
include_recipe 'rabbitmq::mgmt_console'
include_recipe 'rabbitmq::virtualhost_management'
include_recipe 'rabbitmq::policy_management'
include_recipe 'rabbitmq::user_management'
