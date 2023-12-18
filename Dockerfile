# Copyright (c) 2023 Harmoniis
# 
# This software is released under a Proprietary Software License.
# You may not copy, distribute, or modify this software without explicit

# Use the latest Alpine image as the base
FROM gcr.io/google.com/cloudsdktool/google-cloud-cli:448.0.0-alpine

# Set up environment variables
ARG TERRAFORM_VERSION=1.5.7
ARG HELM_VERSION=3.13.0
ARG DOCTL_VERSION=1.99.0
ARG CREDENTIALS=./credentials.json

ENV TERRAFORM_VERSION=${TERRAFORM_VERSION}
ENV HELM_VERSION=${HELM_VERSION}
ENV GOOGLE_APPLICATION_CREDENTIALS="/root/.config/gcloud/application_default_credentials.json"

# Install necessary packages
RUN apk add --update --no-cache \
        bash \
        curl \
        git \
        jq \
        openssh \
        openssl \
        python3 \
        py3-crcmod \
        py3-pip \
        k9s \
        gcompat \
        bind-tools \
    && pip3 install --upgrade pip

# Install Terraform
RUN curl -L -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    && unzip /tmp/terraform.zip -d /usr/local/bin \
    && rm /tmp/terraform.zip

# Install doctl
RUN curl -L -o /tmp/doctl.tar.gz https://github.com/digitalocean/doctl/releases/download/v${DOCTL_VERSION}/doctl-${DOCTL_VERSION}-linux-amd64.tar.gz \
    && tar -zxvf /tmp/doctl.tar.gz -C /tmp \
    && mv /tmp/doctl /usr/local/bin \
    && rm /tmp/doctl.tar.gz

# Install Helm
RUN curl -L -o /tmp/helm.tar.gz https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz \
    && tar -zxvf /tmp/helm.tar.gz -C /tmp \
    && mv /tmp/linux-amd64/helm /usr/local/bin/helm \
    && rm -rf /tmp/linux-amd64 /tmp/helm.tar.gz \
    && helm repo add stable https://charts.helm.sh/stable 

# Install Google Cloud SDK using the build argument for version
RUN gcloud components install kubectl

# Copy the credentials file from the user's environment
COPY ${CREDENTIALS} ${GOOGLE_APPLICATION_CREDENTIALS}

# Set the working directory
WORKDIR /root/src

# Run an entrypoint script to source environment variables
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
