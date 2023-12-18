# Copyright (c) 2023 George Poenaru
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

#!/bin/bash

# Extract CA certificate
ca_certificate=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 --decode)

# Extract API server URL
api_server=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.server}')

# Extract current context name (cluster name)
current_context=$(kubectl config current-context)

# Output the data in JSON format
cat <<EOF
{
  "ca_certificate": "${ca_certificate}",
  "api_server": "${api_server}",
  "cluster_name": "${current_context}"
}
EOF
