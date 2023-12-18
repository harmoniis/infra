# Copyright (c) 2023 George Poenaru
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

#!/bin/bash

# Initialize an empty kubeconfig file
temp_kubeconfig=$(mktemp)

cp /root/.kube/config "$temp_kubeconfig"

# Get args
cloud="$1"
region="$2"

# Check if arguments are provided
if [ -z "$cloud" ]; then
    echo "Usage: $0 <cloud>(optional) <region>(optional)"
    for cloud in $TF_VAR_clouds; do
        sanitized_cloud=$(echo "$cloud" | tr -cd '[:alnum:]-')
        regions_var="TF_VAR_${sanitized_cloud}_regions"
        regions=$(eval echo \$$regions_var)
        for region in regions; do
            sanitized_region=$(echo "$region" | tr -cd '[:alnum:]-')
            if ! kubectl config get-contexts | grep "$sanitized_cloud-$sanitized_region\s"; then
                echo "Context '$sanitized_cloud-$sanitized_region' does not exist in your kubeconfig."
                echo "This means that the cluster is not deployed in $sanitized_cloud region $sanitized_region."
                echo "Please deploy the cluster in all clouds and regions, including $sanitized_cloud region $sanitized_region before applying globaly."
                exit 1
            fi
        done
    done
    echo "Applying global receipe"
    terraform workspace select global
    terraform apply -auto-approve
    TF_VAR_tunnel_id=$(terraform output -raw tunnel_id)
    TF_VAR_tunnel_name=$(terraform output -raw tunnel_name)

    for cloud in $TF_VAR_clouds; do
        sanitized_cloud=$(echo "$cloud" | tr -cd '[:alnum:]-')
        regions_var="TF_VAR_${sanitized_cloud}_regions"
        regions=$(eval echo \$$regions_var)
        for region in regions; do
            sanitized_region=$(echo "$region" | tr -cd '[:alnum:]-')
            if ! kubectl config get-contexts | grep "$sanitized_cloud-$sanitized_region\s"; then
                echo "Context '$sanitized_cloud-$sanitized_region' does not exist in your kubeconfig."
                echo "This means that the cluster is not deployed in $sanitized_cloud region $sanitized_region."
                break
            fi
            region_key="${sanitized_region//-/_}"
            # Construct the variable
            is_tunnel_deployed="TF_VAR_${sanitized_cloud}_${region_key}_tunnel_deployed"
            # Check if the tunnel client is already deployed
            if [ "${!is_tunnel_deployed}" = false ]; then
                echo "The tunnel is deployed in ${sanitized_cloud} region ${sanitized_region}."
                echo "Applying tunnel receipe"
                terraform workspace select "$sanitized_cloud-$sanitized_region"
                TF_VAR_cloud=$sanitized_cloud TF_VAR_region=$sanitized_region terraform apply -auto-approve
                if [[ "$(terraform output -raw tunnel_id 2>/dev/null)" != "null" ]]; then
                    export TF_VAR_${sanitized_cloud}_${region_key}_tunnel_deployed=true
                fi
            fi
        done
    done

    exit 0
fi

## GKE Provision
if [ "$cloud" = "gcp" ] && [ -z "$region" ]; then
    echo "Apply on cloud $cloud in all regions."
    echo "Please provide a workspace name as an argument for single region apply."
    for gcp_region in $TF_VAR_gcp_regions; do

        sanitized_region=$(echo "$gcp_region" | tr -cd '[:alnum:]-')

        # Select the workspace
        terraform workspace select "$cloud-$sanitized_region"

        # Check if the context exists
        if ! kubectl config get-contexts | grep "$cloud-$sanitized_region\s"; then
            echo "Context '$cloud-$sanitized_region' does not exist in your kubeconfig."
            TF_VAR_cloud=$cloud TF_VAR_region=$sanitized_region terraform apply -auto-approve -target=module.region[0].module.cluster

            # Exit if terraform apply fails
            if [ $? -ne 0 ]; then
                echo "Error creating cluster in cloud $cloud region $sanitized_region"
                exit 1
            fi

            # Get the terraform outputs
            cluster_name=$(terraform output -raw gcp_cluster_name)
            project_id=$(terraform output -raw gcp_cluster_project_id)

            # Verify the outputs
            if [ -z "$cluster_name" ]; then
                echo "cluster_name is not defined"
                exit 1
            fi

            if [ -z "$project_id" ]; then
                echo "project_id is not defined"
                exit 1
            fi

            # Run the commands
            echo "getting credentials for cluster $cluster_name in project $project_id from region $sanitized_region"
            gcloud container clusters get-credentials ${cluster_name} --region ${sanitized_region} --project ${project_id}

            # Set context name for the current region's credentials
            kubectl config rename-context "$(kubectl config current-context)" "$cloud-$sanitized_region"

            KUBECONFIG="$temp_kubeconfig:/root/.kube/config"

            # Merge the current kubeconfig with the temp_kubeconfig
            kubectl config view --flatten >"$temp_kubeconfig.tmp"
            mv "$temp_kubeconfig.tmp" "$temp_kubeconfig"
            chmod 600 ~/.kube/config
        fi

        TF_VAR_cloud=$cloud TF_VAR_region=$sanitized_region terraform apply -auto-approve
        if [[ "$(terraform output -raw tunnel_id 2>/dev/null)" != "null" ]]; then
            region_key="${sanitized_region//-/_}"
            export TF_VAR_${cloud}_${region_key}_tunnel_deployed=true
        fi

    done

elif [ "$cloud" = "gcp" ] && [ -n "$region" ]; then
    echo "Creating workspace $cloud-$region..."
    # Select the workspace
    terraform workspace select "$cloud-$region"

    cp ~/.kube/config "$temp_kubeconfig"

    # Verify the outputs
    if ! kubectl config get-contexts | grep "$cloud-$region\s"; then
        echo "cluster_name is not defined so we will create it first."
        TF_VAR_cloud=$cloud TF_VAR_region=$region terraform apply -auto-approve -target=module.region[0].module.cluster

        # Exit if terraform apply fails
        if [ $? -ne 0 ]; then
            echo "Error creating cluster in cloud $cloud region $region"
            exit 1
        fi

        # Get the terraform outputs
        cluster_name=$(terraform output -raw gcp_cluster_name)
        project_id=$(terraform output -raw gcp_cluster_project_id)

        # Verify the outputs
        if [ -z "$cluster_name" ]; then
            echo "cluster_name is not defined"
            exit 1
        fi

        if [ -z "$project_id" ]; then
            echo "project_id is not defined"
            exit 1
        fi

        # Run the commands
        gcloud container clusters get-credentials ${cluster_name} --region ${workspace} --project ${project_id}

        # Set context name for the current region's credentials
        kubectl config rename-context "$(kubectl config current-context)" "$cloud-$region"

        KUBECONFIG="$temp_kubeconfig:/root/.kube/config"

        # Merge the current kubeconfig with the temp_kubeconfig
        kubectl config view --flatten >"$temp_kubeconfig.tmp"
        mv "$temp_kubeconfig.tmp" "$temp_kubeconfig"
        chmod 600 ~/.kube/config

    fi

    TF_VAR_cloud=$cloud TF_VAR_region=$region terraform apply -auto-approve
    if [[ "$(terraform output -raw tunnel_id 2>/dev/null)" != "null" ]]; then
        region_key="${sanitized_region//-/_}"
        export TF_VAR_${cloud}_${region_key}_tunnel_deployed=true
    fi

fi

##############################################################################################

## DO provision
if [ "$cloud" = "do" ] && [ -z "$region" ]; then
    echo "Apply on cloud $cloud in all regions."
    echo "Please provide a workspace name as an argument for single region apply."
    for do_region in $TF_VAR_do_regions; do

        sanitized_region=$(echo "$do_region" | tr -cd '[:alnum:]-')

        # Select the workspace
        terraform workspace select "$cloud-$sanitized_region"

        # Check if the context exists
        if ! kubectl config get-contexts | grep "$cloud-$sanitized_region\s"; then
            echo "Context $cloud-$sanitized_region does not exist in your kubeconfig."
            TF_VAR_cloud=$cloud TF_VAR_region=$sanitized_region terraform apply -auto-approve -target=module.region[0].module.cluster

            # Exit if terraform apply fails
            if [ $? -ne 0 ]; then
                echo "Error creating cluster in cloud $cloud region $sanitized_region"
                exit 1
            fi

            # Get the terraform outputs
            cluster_id=$(terraform output -raw do_cluster_id)
            cluster_urn=$(terraform output -raw do_cluster_urn)

            # Get the terraform outputs
            cluster_id=$(terraform output -raw do_cluster_id)
            cluster_urn=$(terraform output -raw do_cluster_urn)

            # Verify the outputs
            if [ -z "$cluster_id" ]; then
                echo "cluster_id is not defined"
                exit 1
            fi

            if [ -z "$cluster_urn" ]; then
                echo "cluster_urn is not defined"
                exit 1
            fi

            # Run the commands
            echo "getting credentials for cluster $cluster_id in cloud $cloud region $sanitized_region"
            doctl kubernetes cluster kubeconfig save ${cluster_id}

            # Set context name for the current region's credentials
            kubectl config rename-context "$(kubectl config current-context)" "$cloud-$sanitized_region"

            KUBECONFIG="$temp_kubeconfig:/root/.kube/config"

            # Merge the current kubeconfig with the temp_kubeconfig
            kubectl config view --flatten >"$temp_kubeconfig.tmp"
            mv "$temp_kubeconfig.tmp" "$temp_kubeconfig"
            chmod 600 ~/.kube/config
        fi

        TF_VAR_cloud=$cloud TF_VAR_region=$sanitized_region terraform apply -auto-approve
        if [[ "$(terraform output -raw tunnel_id 2>/dev/null)" != "null" ]]; then
            region_key="${sanitized_region//-/_}"
            export TF_VAR_${cloud}_${region_key}_tunnel_deployed=true
        fi

    done

elif [ "$cluster" = "do" ] && [ -n "$region" ]; then
    echo "Creating workspace $cloud-$region..."
    # Select the workspace
    terraform workspace select "$cloud-$region"

    cp ~/.kube/config "$temp_kubeconfig"

    # Verify the outputs
    if ! kubectl config get-contexts | grep "$cloud-$region\s"; then
        echo "cluster_name is not defined so we will create it first."
        TF_VAR_cloud=$cloud TF_VAR_region=$region terraform apply -auto-approve -target=module.region[0].module.cluster

        # Exit if terraform apply fails
        if [ $? -ne 0 ]; then
            echo "Error creating cluster in cloud $cloud region $region"
            exit 1
        fi

        # Get the terraform outputs
        cluster_id=$(terraform output -raw do_cluster_id)
        cluster_urn=$(terraform output -raw do_cluster_urn)

        # Verify the outputs
        if [ -z "$cluster_id" ]; then
            echo "cluster_id is not defined"
            exit 1
        fi

        if [ -z "$cluster_urn" ]; then
            echo "cluster_urn is not defined"
            exit 1
        fi

        # Run the commands
        doctl kubernetes cluster kubeconfig save ${cluster_id}

        # Set context name for the current region's credentials
        kubectl config rename-context "$(kubectl config current-context)" "$cloud-$region"

        KUBECONFIG="$temp_kubeconfig:/root/.kube/config"

        # Merge the current kubeconfig with the temp_kubeconfig
        kubectl config view --flatten >"$temp_kubeconfig.tmp"
        mv "$temp_kubeconfig.tmp" "$temp_kubeconfig"
        chmod 600 ~/.kube/config

    fi

    TF_VAR_cloud=$cloud TF_VAR_region=$region terraform apply -auto-approve
    if [[ "$(terraform output -raw tunnel_id 2>/dev/null)" != "null" ]]; then
        region_key="${sanitized_region//-/_}"
        export TF_VAR_${cloud}_${region_key}_tunnel_deployed=true
    fi

fi

mv "$temp_kubeconfig" ~/.kube/config
chmod 600 ~/.kube/config

echo "Merged kubeconfig saved as the default kubeconfig"
