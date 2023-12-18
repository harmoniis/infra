# Copyright (c) 2023 George Poenaru
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

#!/bin/bash

# Get args
cloud="$1"
region="$2"

# Check if arguments are provided
if [ -z "$cloud" ]; then
    echo "Usage: $0 <cloud>(optional) <region>(optional)"
    echo "Destroying global receipe"
    terraform workspace select global
    terraform destroy -auto-approve
    exit 0
fi

### GCP Destroy

if [ "$cloud" = "gcp" ] && [ -z "$region" ]; then
    echo "Destroy on cloud $cloud in all regions."
    echo "Please provide a workspace name as an argument for single region apply."

    for region in $TF_VAR_gcp_regions; do

        sanitized_region=$(echo "$region" | tr -cd '[:alnum:]-')

        terraform workspace select "$cloud-$sanitized_region"

        TF_VAR_cloud=$cloud TF_VAR_region=$sanitized_region terraform destroy -auto-approve

        # Exit if terraform destroy fails
        if [ $? -ne 0 ]; then
            echo "Error destroy cluster in cloud $cloud region $sanitized_region"
            exit 1
        fi

        kubectl config delete-context "$cloud-$sanitized_region"
    done
elif [ "$cloud" = "gcp" ] && [ -n "$region" ]; then

    echo "Creating workspace $cloud-$region..."
    # Select the workspace
    terraform workspace select "$cloud-$region"

    TF_VAR_cloud=$cloud TF_VAR_region=$region terraform destroy -auto-approve

    # Exit if terraform destroy fails
    if [ $? -ne 0 ]; then
        echo "Error destroying cluster in cloud in region $region"
        exit 1
    fi

    kubectl config delete-context "$cloud-$region"
fi

### Digital Ocean Destroy

if [ "$cloud" = "do" ] && [ -z "$region" ]; then
    echo "Destroy on cloud $cloud in all regions."
    echo "Please provide a workspace name as an argument for single region apply."

    for region in $TF_VAR_do_regions; do

        sanitized_region=$(echo "$region" | tr -cd '[:alnum:]-')

        terraform workspace select "$cloud-$sanitized_region"

        TF_VAR_cloud=$cloud TF_VAR_region=$sanitized_region terraform destroy -auto-approve

        # Exit if terraform destroy fails
        if [ $? -ne 0 ]; then
            echo "Error destroying cluster in cloud $cloud region $sanitized_region"
            exit 1
        fi

        kubectl config delete-context "$cloud-$sanitized_region"
    done

elif [ "$cloud" = "do" ] && [ -n "$region" ]; then

    echo "Creating workspace $cloud-$region..."
    # Select the workspace
    terraform workspace select "$cloud-$region"

    TF_VAR_cloud=$cloud TF_VAR_region=$region terraform destroy -auto-approve

    # Exit if terraform destroy fails
    if [ $? -ne 0 ]; then
        echo "Error destroy cluster in cloud $cloud in region $region"
        exit 1
    fi

    kubectl config delete-context "$cloud-$region"
fi
