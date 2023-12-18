# Harmoniis Infrastructure as Code with Docker Ops Toolset

## Architecture

We use Terraform to deploy the multi cloud, multi regions Harmoniis IaC. Apps and Ops runs in multiple Kubernetes clusters meshed with linkerd accross cloudflare tunnels. Harmoniis microservices will be deployed in the apps env and everything related with gitops or other ops will be deployed in the ops env.

### Infrastructure paradigms:
    * each deployment controls a single stage (dev, staging, prod)
    * linkerd is used as the service mesh also for multi-cluster communication
    * cluster deployment curently supported for GCP(GKE) and DigitalOcean only
    * easy extensible to other cloud providers or on-prem
    * ingress is tunneled and load balanced with CloudFlare
    * the ingress entry point is a CloudFlare DNS record environment dependent (dev.iac, stage.iac, prod.iac)
    * the deployment is fully automated with Terraform

#### TODO:
    * add support for AWS and OpenStack
    * add optionality for TF backend (currently only GCS is supported) 

## Summary: 
In order to deploy a Harmoniis Infrastructure faster, we created a Docker image that includes ops toolset: Terraform, kubectl, Helm, k9s, doctl and GCP SDK. TF state is only supported in GCP currently so you'll need GCP account even if you don't deploy in GCP. To deploy the infrastructure you need to follow the steps below:

1. Get the credentials for your Google Cloud account
2. Set the `GOOGLE_APPLICATION_CREDENTIALS` environment variable in your shell to point to the JSON key file for your Google Cloud account
3. Get your CloudFlare API key (optionaly if you want to deploy in DigitalOcean you need to get your DigitalOcean credentials)
4. Set the .env file with the values for the environment variables specific to deployment
5. Build the Docker image
6. Run the Docker shells
7. Deploy the Harmoniis Infrastructure using the terraform commands

## Prerequisites

Before building the Docker image, make sure to set the `GOOGLE_APPLICATION_CREDENTIALS` environment variable in your shell to point to the JSON key file for your Google Cloud account:

```bash
# Relative to build context (Dockerfile location - root)
# default: ./credentials.json
export GOOGLE_APPLICATION_CREDENTIALS="./path/to/your/credentials.json" 


```

## Build the Docker image

To build the Docker image, navigate to the directory containing the Dockerfile and execute the following command:

```bash
# if credentials.json is default located in the root
docker build -t infra .
# if credentials.json is not in the default location
docker build --build-arg CREDENTIALS=$GOOGLE_APPLICATION_CREDENTIALS -t infra .

```

We give a name to the image we built and we name it  `infra`.

## Create the .env file

Copy the `.env.example` file to a new file named `.env`:

```bash
cp .env.example .env
```

Edit the `.env` file with your preferred text editor and set the values for the environment variables specific to deployment:

```
# .env
see .env.example
```

## Run the Docker shell

To run the Docker shell and mount the "src" directory of this repo as a volume inside the container under "/root/src" path, execute the following command:

```bash
docker run -it -v "$(pwd)"/src:/root/src --env-file .env infra /bin/sh 
```


Now you should be inside the Docker container with access to Terraform, kubectl, Helm, and Google Cloud SDK.

Ready to deploy a Harmoniis Kubernetes cluster in GKE

## Deploying the Harmoniis Kubernetes cluster in GKE

To deploy the Harmoniis Infra use the docker shell to apply or destroy regional, multi-regional or global deployment:

regional cloud deployment:

```bash
./apply.sh <cloud> <region>
./destroy.sh <cloud> <region>
```

multi-regional per cloud deployment:

```bash
./apply.sh <cloud>
./destroy.sh <cloud>
```

global deployment:

```bash
./apply.sh
./destroy.sh
```


## Cluster access
kubectl --kubeconfig=kubeconfig-CLOUD-REGION.yaml get nodes


## Deployment Overview

This graph visualizes the infrastructure deployment structure. 

![Deployment Overview](/doc/deployment.jpg "Deployment Overview")


## Using private repositories in GCP

To use private repositories, you need to login docker to gcloud artifact repository you need to obtain credential json file and authenticate like this:

```bash
gcloud auth activate-service-account --key-file=credentials.json
gcloud auth configure-docker ${region}-docker.pkg.dev
```

In some env you need to edit ~/.docker/config.json and update credsStore to credStore
```bash
nano ~/.docker/config.json
```
## License

```

# Copyright 2023 Harmoniis Inc.
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
```