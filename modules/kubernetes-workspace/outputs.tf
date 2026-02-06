# Kubernetes Workspace Module - Outputs

output "pod_name" {
  description = "Name of the workspace pod"
  value       = var.start_count > 0 ? kubernetes_pod_v1.workspace[0].metadata[0].name : null
}

output "pod_uid" {
  description = "UID of the workspace pod (for coder_metadata resource_id)"
  value       = var.start_count > 0 ? kubernetes_pod_v1.workspace[0].metadata[0].uid : null
}

output "pvc_name" {
  description = "Name of the persistent volume claim"
  value       = kubernetes_persistent_volume_claim_v1.home.metadata[0].name
}

output "namespace" {
  description = "Namespace where resources are created"
  value       = local.namespace
}

output "workspace_size" {
  description = "Computed workspace size category (light, standard, heavy, intensive)"
  value       = local.workspace_size
}

output "resource_name" {
  description = "Base resource name used for pod and other resources"
  value       = local.resource_name
}
