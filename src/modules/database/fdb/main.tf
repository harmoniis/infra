terraform {
  required_providers {

    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.2"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "2.11.0"
    }
    github = {
      source  = "integrations/github"
      version = "5.40.0"
    }
  }
}

locals {
  clone_location = "${path.module}/.gitops"

}

data "github_repository" "fdb-operator" {
  full_name = "FoundationDB/fdb-kubernetes-operator"
}

resource "null_resource" "clone_repo" {

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<EOT
#!/bin/bash

# Define the repository URL and local clone location
repo_url="${data.github_repository.fdb-operator.http_clone_url}"
local_path="${local.clone_location}"

# Check if the repository already exists
if [ -d "$local_path" ]; then
  # If it exists, navigate to the repository directory and pull updates
  cd "$local_path"
  git pull
else
  # If it doesn't exist, clone the repository
  git clone "$repo_url" "$local_path"
fi
EOT

    interpreter = ["bash", "-c"]
  }
}



resource "helm_release" "fdb-operator" {
  name      = "fdb-operator"
  namespace = var.namespace # You can choose a different namespace if desired
  chart     = "${local.clone_location}/charts/fdb-operator"
  #repository = "https://foundationdb.github.io/fdb-kubernetes-operator/"

  values = [
    <<EOF
    initContainers:
      7.1:
        image:
          repository: foundationdb/foundationdb-kubernetes-sidecar
          tag: ${var.tag}-1
          pullPolicy: IfNotPresent
    EOF
  ]

  depends_on = [null_resource.clone_repo]
}

resource "kubectl_manifest" "cluster" {
  depends_on = [helm_release.fdb-operator]

  yaml_body = <<YAML
apiVersion: apps.foundationdb.org/v1beta2
kind: FoundationDBCluster
metadata:
  name: ${var.name}
  namespace: ${var.namespace}
spec:
  automationOptions:
    replacements:
      enabled: true
  faultDomain:
    key: foundationdb.org/none
  labels:
    filterOnOwnerReference: false
    matchLabels:
      foundationdb.org/fdb-cluster-name: ${var.name}
    processClassLabels:
    - foundationdb.org/fdb-process-class
    processGroupIDLabels:
    - foundationdb.org/fdb-process-group-id
  minimumUptimeSecondsForBounce: 60
  processCounts:
    cluster_controller: 1
    stateless: -1
  processes:
    general:
      customParameters:
      - knob_disable_posix_kernel_aio=1
      podTemplate:
        spec:
          containers:
          - name: foundationdb
            resources:
              requests:
                cpu: 100m
                memory: 128Mi
            securityContext:
              runAsUser: 0
          - name: foundationdb-kubernetes-sidecar
            resources:
              limits:
                cpu: 100m
                memory: 128Mi
              requests:
                cpu: 100m
                memory: 128Mi
            securityContext:
              runAsUser: 0
          initContainers:
          - name: foundationdb-kubernetes-init
            resources:
              limits:
                cpu: 100m
                memory: 128Mi
              requests:
                cpu: 100m
                memory: 128Mi
            securityContext:
              runAsUser: 0
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: ${var.storage}
  routing:
    headlessService: true
  sidecarContainer:
    enableLivenessProbe: true
    enableReadinessProbe: false
  useExplicitListenAddress: true
  satelliteRedundancyMode: "one_satellite_double"
  processCounts:
    satellite_logs: ${length(var.datacenters) * 3} 
    satellites: ${length(var.datacenters)}
  datacenters:
    ${join("\n", [for dc in var.datacenters : 
      "- id: \"${dc}\"\n  satellite: 1\n  locality:\n    kubernetes_service_hostname: \"fdb-${dc}-svc.${var.namespace}\"\n    kubernetes_service_port: 4500"])}
  version: ${var.tag}
YAML
}


resource "kubectl_manifest" "backup" {
  depends_on = [kubectl_manifest.cluster]

  yaml_body = <<YAML
apiVersion: apps.foundationdb.org/v1beta2
kind: FoundationDBBackup
metadata:
  name: ${var.name}
  namespace: ${var.namespace}
spec:
  blobStoreConfiguration:
    accountName: minio@minio-service:9000
  clusterName: ${var.name}
  podTemplateSpec:
    spec:
      containers:
      - env:
        - name: FDB_BLOB_CREDENTIALS
          value: /var/backup-credentials/credentials
        - name: FDB_TLS_CERTIFICATE_FILE
          value: /tmp/fdb-certs/tls.crt
        - name: FDB_TLS_CA_FILE
          value: /tmp/fdb-certs/tls.crt
        - name: FDB_TLS_KEY_FILE
          value: /tmp/fdb-certs/tls.key
        name: foundationdb
        resources:
          limits:
            cpu: 250m
            memory: 128Mi
          requests:
            cpu: 250m
            memory: 128Mi
        securityContext:
          runAsGroup: 0
          runAsUser: 0
        volumeMounts:
        - mountPath: /tmp/fdb-certs
          name: fdb-certs
        - mountPath: /var/backup-credentials
          name: backup-credentials
      initContainers:
      - name: foundationdb-kubernetes-init
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
          requests:
            cpu: 100m
            memory: 128Mi
        securityContext:
          runAsUser: 0
      volumes:
      - name: backup-credentials
        secret:
          secretName: minio-credentials
      - name: fdb-certs
        secret:
          secretName: fdb-kubernetes-operator-secrets
  snapshotPeriodSeconds: 3600
  version: ${var.tag}
YAML

}

resource "kubectl_manifest" "restore" {
  depends_on = [kubectl_manifest.backup]

  yaml_body = <<YAML
apiVersion: apps.foundationdb.org/v1beta2
kind: FoundationDBRestore
metadata:
  name: ${var.name}
  namespace: ${var.namespace}
spec:
  blobStoreConfiguration:
    accountName: minio@minio-service:9000
  destinationClusterName: ${var.name}
YAML
}

resource "kubectl_manifest" "config" {
  depends_on = [kubectl_manifest.restore]

  yaml_body = <<YAML
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: ${var.name}-storage
  namespace: ${var.namespace}
spec:
  minAvailable: 5
  selector:
    matchLabels:
      fdb-cluster-name: ${var.name}
      fdb-process-class: storage
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: ${var.name}-log
  namespace: ${var.namespace}
spec:
  minAvailable: 3
  selector:
    matchLabels:
      fdb-cluster-name: ${var.name}
      fdb-process-class: log
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: ${var.name}-transaction
  namespace: ${var.namespace}
spec:
  minAvailable: 3
  selector:
    matchLabels:
      fdb-cluster-name: ${var.name}
      fdb-process-class: transaction
YAML
}

resource "kubectl_manifest" "client" {
  depends_on = [kubectl_manifest.cluster]

  yaml_body = <<YAML
apiVersion: v1
kind: Service
metadata:
  labels:
    app: ${var.name}-client
  name: ${var.name}-client
  namespace: ${var.namespace}
spec:
  ports:
  - port: 9562
    targetPort: 5000
  selector:
    app: ${var.name}-client
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${var.name}-client
  namespace: ${var.namespace}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ${var.name}-client
  template:
    metadata:
      labels:
        app: ${var.name}-client
      name: ${var.name}-client
    spec:
      automountServiceAccountToken: false
      containers:
      - env:
        - name: FDB_CLUSTER_FILE
          value: /var/dynamic-conf/fdb.cluster
        - name: FDB_API_VERSION
          value: "610"
        - name: FDB_NETWORK_OPTION_TRACE_LOG_GROUP
          value: ${var.name}-client
        - name: FDB_NETWORK_OPTION_EXTERNAL_CLIENT_DIRECTORY
          value: /var/dynamic-conf/lib/multiversion
        - name: LD_LIBRARY_PATH
          value: /var/dynamic-conf/lib
        image: foundationdb/foundationdb-sample-python-app:latest
        imagePullPolicy: Always
        name: client
        resources:
          limits:
            cpu: 250m
            memory: 128Mi
          requests:
            cpu: 250m
            memory: 128Mi
        volumeMounts:
        - mountPath: /var/dynamic-conf
          name: dynamic-conf
      initContainers:
      - args:
        - --copy-file
        - fdb.cluster
        - --copy-library
        - "6.2"
        - --copy-library
        - "6.3"
        - --init-mode
        - --require-not-empty
        - fdb.cluster
        image: foundationdb/foundationdb-kubernetes-sidecar:${var.tag}-1
        name: foundationdb-kubernetes-init
        volumeMounts:
        - mountPath: /var/input-files
          name: config-map
        - mountPath: /var/output-files
          name: dynamic-conf
      volumes:
      - configMap:
          items:
          - key: cluster-file
            path: fdb.cluster
          name: ${var.name}-config
        name: config-map
      - emptyDir: {}
        name: dynamic-conf
YAML
}

