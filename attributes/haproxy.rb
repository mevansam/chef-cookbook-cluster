# HAProxy cluster configuration attributes

default['haproxy']['is_clustered'] = false

# The fully qualified domain name of the haproxy endpoint
default['haproxy']['fqdn'] = nil

# If nodes in the pools have not been created yet then 
# all pools will be configured with this default IP.
default['haproxy']['backend_default_ip'] = nil

# Map of name => data bags containing certificates. The name
# of the certificate will be referenced by the 'bind_ssl' to
# configure a certificate of a server pool with an ssl frontend.
default['haproxy']['certificate_databag_items'] = { }

# Virtual IP for haproxy cluster failover
default['haproxy']['virtual_ip_address'] = nil
default['haproxy']['virtual_ip_cidr_netmask'] = nil
default['haproxy']['virtual_ip_nic'] = nil

# AWS Elastic IP
default['haproxy']['is_aws_elastic_ip'] = false

# Map of pool profiles
#
# i.e.
#
# 'profiles' => {
#     <profile_name> => {
#         "mode": "tcp",
#         "balance": "roundrobin",
#         "params": [
#             "option tcplog",
#             "option tcpka",
#             "option mysql-check user haproxy",
#             "timeout client 12h",
#             "timeout server 12h"
#         ],
#         "bind_options": [
#             "accept-proxy"
#         ],
#         "member_options": {
#             "0": "check weight 1",
#             "*": "backup check weight 1"
#         }
#     }
# }
#
default['haproxy']['profiles'] = { }

# Server pools are proxy loadbalancing endpoints
#
# i.e.
#
# 'server_pools' => {
#     <pool_name> => {
#         'cluster_role' => <chef node role used to search for pool members>
#         'port' => <back end port>
#         'profile' => <profile_name> 
# }
#
default['haproxy']['server_pools'] = { }

# Additional configuration and tuning settings
#
# 'haproxy': {
#     "install_method": "source",
#     "source": {
#         "version": "1.5.9",
#         "url": "http://www.haproxy.org/download/1.5/src/haproxy-1.5.9.tar.gz",
#         "checksum": "5f51aa8e20a8a3a11be16bd5f5ef382a5e95526803a89182fe1c15a428564722",
#         "use_pcre": true,
#         "use_openssl": true,
#         "use_zlib": true
#     },
#     "enable_default_http": false,
#     "enable_stats_socket": true,
#     "log": [
#         {
#             "address": "127.0.0.1",
#             "length": 1024,
#             "facility": "local0",
#             "level": "info"
#         }
#     ],
#     "global_parameters": {
#         "pidfile": "/var/run/haproxy.pid",
#         "chroot": "/var/lib/haproxy",
#         "ssl-server-verify": "none",
#         "ulimit-n": "65536",
#         "maxconn": "10240",
#         "tune.bufsize": "32768",
#         "tune.ssl.default-dh-param": 2048
#     },
#     "default_parameters": {
#         "mode": "http",
#         "balance": "roundrobin",
#         "retries": 3
#     },
#     "default_options": [
#         "httplog",
#         "dontlognull",
#         "redispatch"
#     ],
#     "defaults_timeouts": {
#         "connect": "5s",
#         "client": "120s",
#         "server": "120s"
#     },
#     "admin": {
#         "address_bind": "0.0.0.0",
#         "port": 22002
#     },
#     .
#     .
#     .
# }
