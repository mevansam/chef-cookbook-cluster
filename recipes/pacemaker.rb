#
# Cookbook Name:: cluster
# Recipe:: pacemaker
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

platform_family = node['platform_family']
ipaddress = node["ipaddress"]

cluster_name = node["cluster_name"]
unless cluster_name.nil?

    mcast_address = node["pacemaker_mcast_address"]
    mcast_port = node["pacemaker_mcast_port"]

    search_query = "cluster_name:#{cluster_name} AND chef_environment:#{node.chef_environment}"
    Chef::Log.info("Searching for cluster nodes matching: #{search_query}")

    cluster_members = [ ]
    initializing_node_name = nil

    search(:node, search_query).each do |cluster_node|

        # Pick the initializing node to be the lowest order node name
        initializing_node_name = cluster_node.name \
            if initializing_node_name.nil? || cluster_node.name<initializing_node_name

        Chef::Log.info("Found cluster node '#{cluster_node.name}' for role '#{cluster_name}': " +
            "ipaddress = #{cluster_node["ipaddress"]}" +
            "hostname = #{cluster_node["hostname"]}")

        cluster_members << [
            cluster_node["ipaddress"],
            cluster_node["hostname"] ]
    end

    unless shell("which crm", true).empty?
        shell("crm status").lines do |l|

            if l=~/Node .* UNCLEAN \(offline\)/

                f = l.split
                crm_node_id = f[2][/\((.*)\)/, 1]
                crm_node_name = f[1]

                Chef::Log.info("Removing Unclean offline node: id=#{crm_node_id}, name=#{crm_node_name}")

                shell!("crm_node --force -R #{crm_node_id}")
                shell!("cibadmin --delete --obj_type nodes --crm_xml '<node uname=\"#{crm_node_name}\"/>'")
                shell!("cibadmin --delete --obj_type status --crm_xml '<node_state uname=\"#{crm_node_name}\"/>'")
            end
        end
    end

    initializing_node = (initializing_node_name==node.name)
    node.set["cluster_initializing_node"] = initializing_node
    node.save

    case platform_family
        when "debian"

            package "pacemaker"
            package "corosync"
            package "cluster-glue"
            package "resource-agents"

            script "configure service startup" do
                interpreter "bash"
                user "root"
                code <<-EOH

                    update-rc.d -f pacemaker remove
                    update-rc.d pacemaker start 50 1 2 3 4 5 . stop 01 0 6 .

                    if [ -z "`grep START /etc/default/corosync`" ]; then
                        echo "START=yes" >> /etc/default/corosync
                    else
                        sed -i "s|#*START=.*|START=yes|" /etc/default/corosync
                    fi

                    touch /etc/corosync/startup.initialized
                EOH
                notifies :run, "script[restart cluster node services]"
                only_if { !File.exists?("/etc/corosync/startup.initialized") }
            end

            if initializing_node

                ruby_block "generating cluster authorization key" do
                    block do

                        system 'corosync-keygen -l'
                        system 'xxd /etc/corosync/authkey > /etc/corosync/authkey.hex'
                        system 'chmod 0400 /etc/corosync/authkey.hex'

                        auth_key = `cat /etc/corosync/authkey.hex | awk '{printf("%s\\n", \$0)}'`
                        node.set["cluster_authkey"] = auth_key
                        node.save

                        Chef::Log.debug("Saved generated authorization key: #{auth_key}")
                    end
                    only_if { node["cluster_authkey"].nil? }
                    notifies :run, "script[restart cluster node services]"
                end
            else
                ruby_block "saving cluster authorization key" do
                    block do
                        system 'cat /etc/corosync/authkey.hex | xxd -r > /etc/corosync/authkey'
                        system 'chmod 0400 /etc/corosync/authkey'
                    end
                    action :nothing
                    notifies :run, "script[restart cluster node services]"
                end

                ruby_block "retrieving cluster authorization key" do
                    block do
                        timeout = Time.now + 300 # Time out after 5 minutes

                        auth_key = nil
                        while Time.now < timeout

                            auth_cluster_nodes = search( :node, 
                                "#{search_query} AND cluster_initializing_node:true AND cluster_authkey:*" )
                            
                            if auth_cluster_nodes.size>0

                                auth_key = auth_cluster_nodes.first["cluster_authkey"]
                                node.set["cluster_authkey"] = auth_key
                                node.save
                                break
                            end
                            sleep 1
                        end

                        Chef::Application.fatal!("Unable to retrieve cluster authorization key.") if auth_key.nil?

                        authkey_file = "/etc/corosync/authkey.hex"
                        existing_authkey = ::File.exists?(authkey_file) ? ::IO.read(authkey_file) : nil

                        if existing_authkey.nil? || auth_key!=existing_authkey
                            ::File.open(authkey_file, 'w+') { |f| f.write(auth_key) } 
                            resources(:ruby_block => "saving cluster authorization key").run_action(:create)
                        end
                    end
                end
            end

            bind_net_address = ipaddress.gsub(/\.\d+$/, '.0')
            template "/etc/corosync/corosync.conf" do
                source "corosync.conf.erb"
                mode "0644"
                variables(
                    :cluster_name => cluster_name,
                    :cluster_members => cluster_members,
                    :bind_net_address => bind_net_address,
                    :mcast_address => mcast_address,
                    :mcast_port => mcast_port
                )
                notifies :run, "script[restart cluster node services]"
            end

            cluster_members.each do |member|

                hostsfile_entry member[0] do
                    hostname member[1]
                    comment 'Required by corosync to discover cluster members'
                end
            end

            script "restart cluster node services" do
                interpreter "bash"
                user "root"
                code <<-EOH
                    service pacemaker stop
                    service corosync stop
                    service corosync start
                    sleep 10
                    service pacemaker start
                EOH
                action :nothing
            end
        else
            Chef::Application.fatal!("Clustering is not supported on the \"#{platform_family}\" family of platforms.", 999)
    end
end
