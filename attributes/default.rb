# Default attributes for cluster cookbook

# The cluster_name attribute is used to search for the cluster nodes having the same name 
default["cluster_name"] = nil

# Attributes to discover pacemaker cluster nodes common parameters
default["pacemaker_mcast_address"] = nil
default["pacemaker_mcast_port"] = nil
