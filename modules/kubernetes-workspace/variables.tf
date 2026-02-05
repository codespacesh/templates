# Kubernetes Workspace Module - Variables
# Shared module for creating Coder workspaces on Kubernetes with sysbox-runc

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "namespace" {
  type        = string
  description = "Kubernetes namespace for workspaces (inherited from tenant provisioning)"
}

variable "workspace_id" {
  type        = string
  description = "Coder workspace ID"
}

variable "workspace_name" {
  type        = string
  description = "Coder workspace name"
}

variable "owner_name" {
  type        = string
  description = "Coder workspace owner name"
}

variable "agent_token" {
  type        = string
  sensitive   = true
  description = "Coder agent token"
}

variable "agent_init_script" {
  type        = string
  description = "Coder agent init script"
}

variable "start_count" {
  type        = number
  description = "Number of workspace instances to start (0 or 1)"
}

# =============================================================================
# CONTAINER IMAGE
# =============================================================================

variable "image" {
  type        = string
  description = "Container image for the workspace"
}

variable "image_pull_policy" {
  type        = string
  description = "Image pull policy"
  default     = "Always"
}

# =============================================================================
# COMPUTE RESOURCES
# =============================================================================

variable "cpu_cores" {
  type        = string
  description = "Number of CPU cores (limit)"
  default     = "4"
}

variable "memory_gb" {
  type        = string
  description = "Memory in GB (limit)"
  default     = "8"
}

variable "disk_size_gb" {
  type        = string
  description = "Disk size for home directory PVC in GB"
  default     = "50"
}

variable "cpu_request_ratio" {
  type        = number
  description = "CPU request as ratio of limit (0.0-1.0)"
  default     = 0.25
}

variable "memory_request_ratio" {
  type        = number
  description = "Memory request as ratio of limit (0.0-1.0)"
  default     = 0.5
}

# =============================================================================
# ENVIRONMENT VARIABLES
# =============================================================================

variable "env_vars" {
  type        = map(string)
  description = "Environment variables to pass to the container"
  default     = {}
  sensitive   = true
}

# =============================================================================
# NODE SELECTION
# =============================================================================

variable "use_workspace_size_affinity" {
  type        = bool
  description = "Enable node affinity based on workspace size"
  default     = false
}

# =============================================================================
# LABELS AND ANNOTATIONS
# =============================================================================

variable "extra_labels" {
  type        = map(string)
  description = "Additional labels to apply to resources"
  default     = {}
}

variable "extra_annotations" {
  type        = map(string)
  description = "Additional annotations to apply to resources"
  default     = {}
}
