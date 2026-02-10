# Kubernetes Workspace Module - Main
# Creates K8s pods with sysbox-runc for Coder workspaces

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.37"
    }
  }
}

# =============================================================================
# AUTO-DETECT NAMESPACE FROM SERVICE ACCOUNT
# =============================================================================

# When running in-cluster, read namespace from service account
data "local_file" "namespace" {
  count    = var.namespace == "" ? 1 : 0
  filename = "/var/run/secrets/kubernetes.io/serviceaccount/namespace"
}

# =============================================================================
# LOCALS
# =============================================================================

locals {
  # Use provided namespace or auto-detect from service account
  namespace = var.namespace != "" ? var.namespace : trimspace(data.local_file.namespace[0].content)

  # Resource naming
  resource_name = "coder-${var.owner_name}-${lower(var.workspace_name)}"
  pvc_name      = "coder-${var.workspace_id}-home"

  # Compute workspace size category for node affinity
  workspace_size = (
    tonumber(var.cpu_cores) >= 16 ? "intensive" :
    tonumber(var.cpu_cores) >= 8 ? "heavy" :
    tonumber(var.cpu_cores) >= 4 ? "standard" : "light"
  )

  # Standard labels for all resources
  common_labels = merge({
    "app.kubernetes.io/name"       = "coder-workspace"
    "app.kubernetes.io/instance"   = local.resource_name
    "app.kubernetes.io/managed-by" = "coder"
    "coder.workspace_id"           = var.workspace_id
    "coder.workspace_name"         = var.workspace_name
    "coder.owner"                  = var.owner_name
  }, var.extra_labels)

  # Convert env_vars map to list of env blocks
  env_list = [
    for k, v in var.env_vars : {
      name  = k
      value = v
    }
  ]
}

# =============================================================================
# PERSISTENT VOLUME CLAIM
# =============================================================================

resource "kubernetes_persistent_volume_claim_v1" "home" {
  metadata {
    name        = local.pvc_name
    namespace   = local.namespace
    labels      = local.common_labels
    annotations = var.extra_annotations
  }

  wait_until_bound = false

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${var.disk_size_gb}Gi"
      }
    }
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
    ]
  }
}

# =============================================================================
# WORKSPACE POD
# =============================================================================

resource "kubernetes_pod_v1" "workspace" {
  count = var.start_count

  metadata {
    name        = local.resource_name
    namespace   = local.namespace
    labels      = local.common_labels
    annotations = var.extra_annotations
  }

  spec {
    # Sysbox runtime for Docker-in-Docker support
    runtime_class_name = "sysbox-runc"

    # Image pull secrets for private registries
    dynamic "image_pull_secrets" {
      for_each = var.image_pull_secrets
      content {
        name = image_pull_secrets.value
      }
    }

    # Security context — run as root for DinD (sysbox isolates via user namespaces)
    dynamic "security_context" {
      for_each = var.run_as_root ? [] : [1]
      content {
        run_as_user  = 1000
        run_as_group = 1000
        fs_group     = 1000
      }
    }

    # Optional node affinity based on workspace size
    dynamic "affinity" {
      for_each = var.use_workspace_size_affinity ? [1] : []
      content {
        node_affinity {
          preferred_during_scheduling_ignored_during_execution {
            weight = 100
            preference {
              match_expressions {
                key      = "workspace-size"
                operator = "In"
                values   = [local.workspace_size]
              }
            }
          }
        }
      }
    }

    # Restart policy - don't restart on failure (Coder manages lifecycle)
    restart_policy = "Never"

    # Termination grace period
    termination_grace_period_seconds = 30

    container {
      name              = "workspace"
      image             = var.image
      image_pull_policy = var.image_pull_policy
      command           = ["sh", "-c", var.agent_init_script]

      # Core environment variables
      env {
        name  = "CODER_AGENT_TOKEN"
        value = var.agent_token
      }

      # Additional environment variables
      dynamic "env" {
        for_each = local.env_list
        content {
          name  = env.value.name
          value = env.value.value
        }
      }

      # Home directory volume mount
      volume_mount {
        name       = "home"
        mount_path = "/home/coder"
      }

      # Resource requests and limits
      resources {
        requests = {
          cpu    = "${tonumber(var.cpu_cores) * var.cpu_request_ratio}"
          memory = "${tonumber(var.memory_gb) * var.memory_request_ratio}Gi"
        }
        limits = {
          cpu    = var.cpu_cores
          memory = "${var.memory_gb}Gi"
        }
      }
    }

    # Home directory volume
    volume {
      name = "home"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim_v1.home.metadata[0].name
      }
    }
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
    ]
  }
}
