# OpenClaw Coder Template Module
# AI agent development environment
# Uses Kubernetes with sysbox-runc for Docker-in-Docker support

terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.37"
    }
  }
}


# =============================================================================
# VARIABLES
# =============================================================================

variable "namespace" {
  type        = string
  description = "Kubernetes namespace for workspaces (auto-detected if empty)"
  default     = ""
}

variable "project_name" {
  type        = string
  description = "Name of the project"
}

variable "git_repo" {
  type        = string
  description = "Git repository URL"
  default     = ""
}

# AI Provider credentials
variable "anthropic_api_key" {
  type        = string
  sensitive   = true
  description = "Anthropic API key for Claude"
  default     = ""
}

variable "openai_api_key" {
  type        = string
  sensitive   = true
  description = "OpenAI API key"
  default     = ""
}

# Optional messaging channel configs
variable "telegram_bot_token" {
  type        = string
  sensitive   = true
  description = "Telegram bot token"
  default     = ""
}

variable "discord_bot_token" {
  type        = string
  sensitive   = true
  description = "Discord bot token"
  default     = ""
}

variable "slack_bot_token" {
  type        = string
  sensitive   = true
  description = "Slack bot token"
  default     = ""
}

variable "whatsapp_phone_id" {
  type        = string
  description = "WhatsApp Business phone ID"
  default     = ""
}

variable "whatsapp_token" {
  type        = string
  sensitive   = true
  description = "WhatsApp Business API token"
  default     = ""
}

variable "openclaw_config" {
  type        = string
  description = "Custom OpenClaw config JSON"
  default     = ""
}

variable "dockerhub_username" {
  type        = string
  description = "Docker Hub username"
  default     = ""
}

variable "dockerhub_token" {
  type        = string
  sensitive   = true
  description = "Docker Hub token"
  default     = ""
}

variable "image" {
  type        = string
  description = "Container image for the workspace (empty = use template default)"
  default     = ""
}

variable "image_pull_secrets" {
  type        = list(string)
  description = "Image pull secret names for private registries"
  default     = []
}

# =============================================================================
# CODER DATA SOURCES
# =============================================================================

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# =============================================================================
# PARAMETERS
# =============================================================================

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU Cores"
  description  = "Number of CPU cores for your workspace"
  default      = "4"
  mutable      = true
  option {
    name  = "2 Cores (Light)"
    value = "2"
  }
  option {
    name  = "4 Cores (Standard)"
    value = "4"
  }
  option {
    name  = "8 Cores (Heavy)"
    value = "8"
  }
  option {
    name  = "16 Cores (Intensive)"
    value = "16"
  }
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory (GB)"
  description  = "RAM for your workspace"
  default      = "8"
  mutable      = true
  option {
    name  = "4 GB"
    value = "4"
  }
  option {
    name  = "8 GB"
    value = "8"
  }
  option {
    name  = "16 GB"
    value = "16"
  }
  option {
    name  = "32 GB"
    value = "32"
  }
}

data "coder_parameter" "disk_size" {
  name         = "disk_size"
  display_name = "Disk Size (GB)"
  description  = "Storage for home directory and Docker images"
  default      = "50"
  type         = "number"
  mutable      = false
  validation {
    min = 20
    max = 500
  }
}

# =============================================================================
# CODER AGENT
# =============================================================================

resource "coder_agent" "main" {
  os   = "linux"
  arch = data.coder_provisioner.me.arch

  startup_script = <<-EOT
    #!/bin/bash
    set -e

    # Setup Docker
    /opt/coder-scripts/setup-docker.sh

    # Start XFCE desktop
    /opt/coder-scripts/start-desktop.sh

    # Setup OpenClaw
    /opt/coder-scripts/setup-openclaw.sh

    # Clone repo if provided
    if [ -n "${var.git_repo}" ] && [ ! -d ~/project ]; then
      git clone ${var.git_repo} ~/project
    fi
  EOT

  metadata {
    key          = "runtime"
    display_name = "Runtime"
    value        = "OpenClaw + XFCE + Docker (Kubernetes)"
  }
}

# =============================================================================
# KUBERNETES WORKSPACE (shared module)
# =============================================================================

module "workspace" {
  source = "git::https://github.com/codespacesh/templates.git//modules/kubernetes-workspace?ref=v1.0.1"

  namespace         = var.namespace
  workspace_id      = data.coder_workspace.me.id
  workspace_name    = data.coder_workspace.me.name
  owner_name        = data.coder_workspace_owner.me.name
  agent_token       = coder_agent.main.token
  agent_init_script = coder_agent.main.init_script
  start_count       = data.coder_workspace.me.start_count

  image              = var.image != "" ? var.image : "ghcr.io/codespacesh/openclaw:latest"
  image_pull_policy  = "Always"
  image_pull_secrets = var.image_pull_secrets

  cpu_cores    = data.coder_parameter.cpu.value
  memory_gb    = data.coder_parameter.memory.value
  disk_size_gb = data.coder_parameter.disk_size.value

  env_vars = {
    ANTHROPIC_API_KEY  = var.anthropic_api_key
    OPENAI_API_KEY     = var.openai_api_key
    TELEGRAM_BOT_TOKEN = var.telegram_bot_token
    DISCORD_BOT_TOKEN  = var.discord_bot_token
    SLACK_BOT_TOKEN    = var.slack_bot_token
    WHATSAPP_PHONE_ID  = var.whatsapp_phone_id
    WHATSAPP_TOKEN     = var.whatsapp_token
    OPENCLAW_CONFIG    = var.openclaw_config
    DOCKERHUB_USERNAME = var.dockerhub_username
    DOCKERHUB_TOKEN    = var.dockerhub_token
  }

  use_workspace_size_affinity = true
}

# =============================================================================
# APPS
# =============================================================================

resource "coder_app" "vnc" {
  agent_id     = coder_agent.main.id
  slug         = "vnc"
  display_name = "Desktop"
  icon         = "/icon/desktop.svg"
  url          = "http://localhost:6080/vnc.html"
  subdomain    = true
  share        = "authenticated"
}

resource "coder_app" "openclaw" {
  agent_id     = coder_agent.main.id
  slug         = "openclaw"
  display_name = "OpenClaw"
  icon         = "/icon/terminal.svg"
  url          = "http://localhost:3000"
  subdomain    = true
  share        = "authenticated"
}

# =============================================================================
# METADATA
# =============================================================================

resource "coder_metadata" "workspace" {
  count       = data.coder_workspace.me.start_count
  resource_id = module.workspace.pod_uid

  item {
    key   = "Runtime"
    value = "OpenClaw (Kubernetes)"
  }

  item {
    key   = "CPU"
    value = "${data.coder_parameter.cpu.value} cores"
  }

  item {
    key   = "Memory"
    value = "${data.coder_parameter.memory.value} GB"
  }

  item {
    key   = "Disk"
    value = "${data.coder_parameter.disk_size.value} GB"
  }
}
