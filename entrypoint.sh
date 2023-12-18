#!/bin/sh

# Set the bucket name
export BACKEND_BUCKET_NAME="gs://${TF_VAR_project_name}-tf-state"

# Set the nameserver
echo "nameserver 8.8.8.8" >/etc/resolv.conf

# Authenticate with Google Cloud SDK
gcloud auth activate-service-account --key-file="${GOOGLE_APPLICATION_CREDENTIALS}"
gcloud config set project ${TF_VAR_gcp_project_id}
#gcloud services enable compute.googleapis.com --project ${TF_VAR_gcp_project_id}
gcloud services enable container.googleapis.com --project ${TF_VAR_gcp_project_id}
gcloud services enable iam.googleapis.com --project ${TF_VAR_gcp_project_id}
gcloud services enable artifactregistry.googleapis.com --project ${TF_VAR_gcp_project_id}
gcloud services enable iap.googleapis.com --project ${TF_VAR_gcp_project_id}
gcloud services enable cloudresourcemanager.googleapis.com --project ${TF_VAR_gcp_project_id}
gcloud services enable storage.googleapis.com --project ${TF_VAR_gcp_project_id}
gcloud components install gke-gcloud-auth-plugin --project ${TF_VAR_gcp_project_id}

# Authenticate DigitalOcean
doctl auth init --access-token ${TF_VAR_do_token}

#Add execution mod
chmod +x get_kubeconfig_data.sh

# Check if the bucket already exists
bucket_exists=$(
  gsutil ls -b -L $BACKEND_BUCKET_NAME >/dev/null 2>&1
  echo $?
)

# If the bucket does not exist, create it
echo "Checking if the bucket $BACKEND_BUCKET_NAME exists..."
echo "Bucket exists: $bucket_exists"
# If the bucket does not exist, create it
if [ $bucket_exists -eq 0 ]; then
  echo "The bucket $BACKEND_BUCKET_NAME already exists."
else
  gcloud storage buckets create $BACKEND_BUCKET_NAME --project "${TF_VAR_gcp_project_id}" --location "US"
  # Enable versioning on the bucket
  gsutil versioning set on $BACKEND_BUCKET_NAME
fi

# Create the backend.tf file
cat <<EOF >backend.tf
terraform {
  backend "gcs" {
    bucket  = "${TF_VAR_project_name}-tf-state"
    prefix = "${TF_VAR_env_name}/${TF_VAR_project_name}.tfstate"
  }
}
EOF

# Make scripts executable
chmod +x ./destroy-state.sh
chmod +x ./apply.sh
chmod +x ./destroy.sh

REPOSITORY_ID="images"
FORMAT="DOCKER"

# Create Artifact Repository in GCP if does not exist
for region in $$TF_VAR_gcp_regions; do

  sanitized_region=$(echo "$region" | tr -cd '[:alnum:]-')

  # Check if the repository exists
  EXISTING_REPO=$(gcloud artifacts repositories describe "${REPOSITORY_ID}" \
    --location="${sanitized_region}" \
    --project="${TF_VAR_gcp_project_id}" \
    --repository-format="value(name)" 2>/dev/null)

  # Create the repository if it doesn't exist
  if [[ -n "${EXISTING_REPO}" ]]; then
    gcloud artifacts repositories create "${REPOSITORY_ID}" \
      --location="${sanitized_region}" \
      --project="${TF_VAR_gcp_project_id}" \
      --repository-format="${FORMAT}"

    echo "Artifact repository created."
  else
    echo "Artifact repository already exists."
  fi

done

terraform init

# Check if the global workspace exists and create it if it does not    # Check if the workspace has a deployed state
# Fetch all workspaces
workspaces=$(terraform workspace list)

# Check if the workspace already exists
if echo "$workspaces" | grep -q "global"; then
  echo "Workspace global already exists."
else
  # If the workspace does not exist, create it
  echo "Creating workspace global..."
  terraform workspace new "global"
fi

# Initialize an empty kubeconfig file
temp_kubeconfig=$(mktemp)

# Initialize an empty string for origins map
# This will be constructed as a JSON to be passed to the terraform input variable map
origins=""

# Map DigitalOcean and GCP regions to their CloudFlare respective continents
get_cf_region() {
  cloud=$1
  region=$2
  case "${cloud}-${region}" in
  "do-nyc1" | "do-nyc3" | "do-tor1") echo "ENAM" ;;
  "do-ams3" | "do-lon1" | "do-fra1") echo "WEU" ;;
  "do-sfo2" | "do-sfo3") echo "WNAM" ;;
  "do-sgp1") echo "SEAS" ;;
  "do-blr1") echo "SAS" ;;
  "do-syd1") echo "OC" ;;
  "gcp-asia-east1" | "gcp-asia-east2" | "gcp-asia-northeast1" | "gcp-asia-northeast2" | "gcp-asia-northeast3") echo "NEAS" ;;
  "gcp-asia-south1" | "gcp-asia-south2") echo "SAS" ;;
  "gcp-asia-southeast1" | "gcp-asia-southeast2") echo "SEAS" ;;
  "gcp-australia-southeast1" | "gcp-australia-southeast2") echo "OC" ;;
  "gcp-europe-north1" | "gcp-europe-central2" | "gcp-europe-southwest1" | "gcp-europe-west1" | "gcp-europe-west2" | "gcp-europe-west3" | "gcp-europe-west4" | "gcp-europe-west6" | "gcp-europe-west8" | "gcp-europe-west9" | "gcp-europe-west12") echo "WEU" ;;
  "gcp-northamerica-northeast1" | "gcp-northamerica-northeast2" | "gcp-us-central1" | "gcp-us-east1" | "gcp-us-east4" | "gcp-us-east5" | "gcp-us-west1" | "gcp-us-west2" | "gcp-us-west3" | "gcp-us-west4" | "gcp-us-south1") echo "ENAM" ;;
  "gcp-southamerica-east1" | "gcp-southamerica-west1") echo "NSAM" ;;
  "gcp-me-central1") echo "ME" ;;
  *) echo "UNKNOWN" ;;
  esac
}

for cloud in $TF_VAR_clouds; do
  sanitized_cloud=$(echo "$cloud" | tr -cd '[:alnum:]-')

  echo "Star $sanitized_cloud cloud config..."

  # Construct the variable name and retrieve its value
  regions_var_name="TF_VAR_${sanitized_cloud}_regions"
  regions=$(eval echo \$$regions_var_name)

  # Select the workspace
  for region in $regions; do
    sanitized_region=$(echo "$region" | tr -cd '[:alnum:]-')
    region_key=$(echo "$sanitized_region" | sed 's/-/_/g')
    export TF_VAR_${sanitized_cloud}_${region_key}_tunnel_deployed=false

    cf_region=$(get_cf_region "$sanitized_cloud" "$sanitized_region")
    echo "Cloudflare region: $cf_region for cloud $sanitized_cloud and region $sanitized_region"

    # Initialize origin_entry as a key with an empty array
    origin_entry="\"$cf_region\": []"

    # Append cloud-region pair to the origin map under the Cloudflare region key as an array element
    if [ "$cf_region" != "UNKNOWN" ]; then
      # Append the region to the array in origin_entry
      # This will add the string to the array, creating an entry like "key": ["string"]
      if [ "$origin_entry" = "\"$cf_region\": []" ]; then
        # First entry for this region
        origin_entry="\"$cf_region\": [\"${sanitized_cloud}-${sanitized_region}\"]"
      else
        # Subsequent entries for this region
        # Remove the closing "]" and append the new string
        origin_entry="${origin_entry%?}, \"${sanitized_cloud}-${sanitized_region}\"]"
      fi
      # Append to the origin string
      if [ -z "$origins" ]; then
        origins="$origin_entry"
      else
        origins="${origins},$origin_entry"
      fi
    fi

    # Fetch all workspaces
    workspaces=$(terraform workspace list)

    # Check if the workspace already exists
    if echo "$workspaces" | grep -q "$sanitized_region"; then
      echo "Workspace $sanitized_cloud-$sanitized_region already exists."
    else
      # If the workspace does not exist, create it
      echo "Creating workspace $sanitized_cloud-$sanitized_region..."
      terraform workspace new "$sanitized_cloud-$sanitized_region"
    fi

    # Select the workspace
    terraform workspace select "$sanitized_cloud-$sanitized_region"

    if [[ "$(terraform output -raw tunnel_id 2>/dev/null)" != "null" ]]; then
      export TF_VAR_${sanitized_cloud}_${region_key}_tunnel_deployed=true
    fi

    # Check if the directory exists, if not, create it
    if [ ! -d "/root/.kube" ]; then
      mkdir -p /root/.kube
    fi

    # Check if /root/.kube/config exists, if not initialize it
    if [ ! -f "/root/.kube/config" ]; then
      echo "apiVersion: v1
kind: Config
clusters: []
contexts:
  - name: 'none-none'
    context: {}
current-context: ''
preferences: {}
users: []" >/root/.kube/config
      cp /root/.kube/config "$temp_kubeconfig"
    fi

    # Check if the workspace has a deployed state
    state=$(terraform show -json)
    if echo "$state" | grep -q "resources"; then
      echo "Workspace $sanitized_cloud-$sanitized_region has a deployed state."
    else
      echo "Workspace $sanitized_cloud-$sanitized_region does not have a deployed state. Exiting..."
      continue
    fi

    # Check if region is a valid GCP region
    gcloud_region_check=$(gcloud compute regions list --format="value(name)" | grep "^$region$")
    if [ -n "$gcloud_region_check"] && [ "$sanitized_cloud" = "gcp" ] && terraform output -raw gcp_cluster_name >/dev/null 2>&1 && terraform output -raw gcp_cluster_project_id >/dev/null 2>&1; then
      echo "GCP Cluster Exists"
      # Get the GCP terraform outputs
      gcp_cluster_name=$(terraform output -raw gcp_cluster_name)
      gcp_project_id=$(terraform output -raw gcp_cluster_project_id)

      echo "getting credentials for cluster ${gcp_cluster_name} in project ${gcp_project_id} from region ${sanitized_region}"
      gcloud container clusters get-credentials ${gcp_cluster_name} --region ${sanitized_region} --project ${gcp_project_id}

      # Set context name for the current region's credentials
      kubectl config rename-context "$(kubectl config current-context)" "${sanitized_cloud}-${sanitized_region}"

      KUBECONFIG="$temp_kubeconfig:/root/.kube/config"

      # Merge the current kubeconfig with the temp_kubeconfig
      kubectl config view --flatten >"$temp_kubeconfig.tmp"
      mv "$temp_kubeconfig.tmp" "$temp_kubeconfig"
      chmod 600 /root/.kube/config

    fi

    # Check if the region is in the DigitalOcean regions
    do_region_check=$(doctl compute region list --format="Slug" --no-header | grep "^$region$")
    if [ -n "$do_region_check"] && [ "$sanitized_cloud" = "do" ] && terraform output -raw do_cluster_id >/dev/null 2>&1 && terraform output -raw do_cluster_urn >/dev/null 2>&1; then
      echo "DigitalOcean Cluster Exists"
      # Get the DigitalOcean terraform outputs
      do_cluster_id=$(terraform output -raw do_cluster_id)
      do_cluster_urn=$(terraform output -raw do_cluster_urn)

      echo "getting credentials for cluster ${do_cluster_id} from region ${sanitized_region} in cloud ${sanitized_cloud}"
      doctl kubernetes cluster kubeconfig save ${do_cluster_id}

      # Set context name for the current region's credentials
      kubectl config rename-context "$(kubectl config current-context)" "${sanitized_cloud}-${sanitized_region}"

      KUBECONFIG="$temp_kubeconfig:/root/.kube/config"

      # Merge the current kubeconfig with the temp_kubeconfig
      kubectl config view --flatten >"$temp_kubeconfig.tmp"
      mv "$temp_kubeconfig.tmp" "$temp_kubeconfig"
      chmod 600 /root/.kube/config
    fi
  done
done

# Export the origins JSON for terraform input variable
origins="{${origins}}"
export TF_VAR_origins="$origins"

mv "$temp_kubeconfig" /root/.kube/config
echo "Merged kubeconfig saved as the default kubeconfig"

# Run the provided command
exec "$@"
