#
# Cookbook Name:: cluster
# Recipe:: percona
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

# Setup certs for MySql ssl configuration
if node["percona"]["mysql"]["ssl"] &&
    !node["percona"]["mysql"]["certificate_databag_item"].nil? &&
    !node["percona"]["mysql"]["certificate_databag_item"].empty?

    encryption_key = ::SysUtils::get_encryption_secret(node)
    certificates = Chef::EncryptedDataBagItem.load( "certificates-#{node.chef_environment}", 
        node["percona"]["mysql"]["certificate_databag_item"], encryption_key )

    mysql_config_path = node["percona"]["mysql"]["config_path"]
    directory mysql_config_path

    cacert_path = "#{mysql_config_path}/cacert.pem"
    cert_path = "#{mysql_config_path}/cert.pem"
    key_path = "#{mysql_config_path}/key.pem"

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

    include_dir = node["percona"]["server"]["includedir"]
    directory include_dir

    template "#{include_dir}/mysql_ssl.cnf" do
        source "mysql_ssl.cnf.erb"
        mode "0644"
        variables(
            :cacert => cacert_path,
            :cert => cert_path,
            :key => key_path
        )
    end
end

# If extra storage was provided use that as the data path
node.override["percona"]["server"]["datadir"] = node["env"]["data_path"] \
    unless node["env"]["data_path"].nil? || node["env"]["data_path"].empty?

# Set encrypted password databag by environment
node.override["percona"]["encrypted_data_bag"] = "passwords-#{node.chef_environment}"

# Setup the Percona XtraDB Cluster
cluster_name = node["cluster_name"]

search_query = "cluster_name:#{cluster_name} AND chef_environment:#{node.chef_environment}"
Chef::Log.info("Searching for cluster nodes matching: #{search_query}")

cluster_ips = []
initializing_node_name = nil

search(:node, search_query).each do |percona_node|

    # Pick the initializing node to be the lowest order node name
    initializing_node_name = percona_node.name \
        if initializing_node_name.nil? || percona_node.name<initializing_node_name

    next if percona_node["ipaddress"]==node["ipaddress"]

    Chef::Log.info "Found Percona XtraDB cluster peer: #{percona_node['ipaddress']}"
    cluster_ips << percona_node["ipaddress"]
end

initializing_node = (initializing_node_name==node.name)
if initializing_node && !node["cluster_initializing_node"]
    cluster_address = "gcomm://"
else
    cluster_address = "gcomm://#{cluster_ips.join(',')}"
    node.override["percona"]["skip_passwords"] = true
end

node.set["cluster_initializing_node"] = initializing_node
node.save

Chef::Log.info("Percona XtraDB cluster address is: #{cluster_address}")
node.override["percona"]["cluster"]["wsrep_cluster_name"] = cluster_name
node.override["percona"]["cluster"]["wsrep_cluster_address"] = cluster_address
node.override["percona"]["cluster"]["wsrep_node_name"] = node['hostname']

cluster_ips.each do |ip|

    firewall_rule "allow Percona group communication to peer #{ip}" do
        source ip
        port 4567
        action :allow
    end

    firewall_rule "allow Percona state transfer to peer #{ip}" do
        source ip
        port 4444
        action :allow
    end

    firewall_rule "allow Percona incremental state transfer to peer #{ip}" do
        source ip
        port 4568
        action :allow
    end
end

include_recipe 'percona::cluster'
include_recipe 'percona::backup'
include_recipe 'percona::toolkit'

template = resources(template: "#{node['percona']['main_config_file']}")
template.cookbook("percona")
template.source("my.cnf.cluster.erb")

## Add haproxy user for haproxy mysql health check

if initializing_node

    haproxy_cluster_name = node["percona"]["haproxy_cluster_name"]
    unless haproxy_cluster_name.nil?

        haproxy_user_insert = "USE mysql; DELETE FROM user WHERE User='haproxy';"
        search(:node, "cluster_name:#{haproxy_cluster_name} AND chef_environment:#{node.chef_environment}").each do |haproxy_node|

            Chef::Log.info("Found haproxy cluster node '#{haproxy_node.name}' for cluster '#{haproxy_cluster_name}'.")
            haproxy_user_insert += " INSERT INTO user (Host, User) values ('#{haproxy_node["ipaddress"]}', 'haproxy');"
        end
        haproxy_user_insert += " FLUSH PRIVILEGES;"

        script "Create haproxy user" do
            interpreter "bash"
            user "root"
            cwd "/tmp"
            code <<-EOH
                mysql -e "#{haproxy_user_insert}"
                [ $? -eq 0 ] || exit $?
            EOH
        end
    end
end
