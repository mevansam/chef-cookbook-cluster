# Percona cluster configuration attributes

# Name of HAproxy cluster for which a use will be setup for health checks
default["percona"]["haproxy_cluster_name"] = nil

default["percona"]["mysql"]["ssl"] = false
default["percona"]["mysql"]["config_path"] = "/etc/mysql"
default["percona"]["mysql"]["certificate_databag_item"] = nil

default["percona"]["openstack"]["services"] = [ ]
