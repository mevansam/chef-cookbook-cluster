# Elasticsearch cluster configuration attributes

include_attribute "elasticsearch::default"
include_attribute "elasticsearch::nginx"
include_attribute "elasticsearch::proxy"

default["elasticsearch"]["certificate_databag_item"] = nil

default["elasticsearch"]["nginx"]["ssl"]["cert_file"] = nil
default["elasticsearch"]["nginx"]["ssl"]["key_file"] = nil