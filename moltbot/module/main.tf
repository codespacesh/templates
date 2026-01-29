terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
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

variable "moltbot_config" {
  type        = string
  description = "Custom Moltbot config JSON"
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

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

resource "docker_volume" "home" {
  name = "coder-${data.coder_workspace.me.id}-home"
  lifecycle {
    ignore_changes = all
  }
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  name  = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
  image = "ghcr.io/codespacesh/moltbot:latest"

  hostname   = data.coder_workspace.me.name
  entrypoint = ["sh", "-c", coder_agent.main.init_script]
  runtime    = "sysbox-runc"

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "ANTHROPIC_API_KEY=${var.anthropic_api_key}",
    "OPENAI_API_KEY=${var.openai_api_key}",
    "TELEGRAM_BOT_TOKEN=${var.telegram_bot_token}",
    "DISCORD_BOT_TOKEN=${var.discord_bot_token}",
    "SLACK_BOT_TOKEN=${var.slack_bot_token}",
    "WHATSAPP_PHONE_ID=${var.whatsapp_phone_id}",
    "WHATSAPP_TOKEN=${var.whatsapp_token}",
    "MOLTBOT_CONFIG=${var.moltbot_config}",
    "DOCKERHUB_USERNAME=${var.dockerhub_username}",
    "DOCKERHUB_TOKEN=${var.dockerhub_token}",
  ]

  volumes {
    volume_name    = docker_volume.home.name
    container_path = "/home/coder"
    read_only      = false
  }

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }
}

resource "coder_agent" "main" {
  os             = "linux"
  arch           = "amd64"
  startup_script = <<-EOT
    #!/bin/bash
    set -e

    # Setup Docker
    /opt/coder-scripts/setup-docker.sh

    # Start XFCE desktop
    /opt/coder-scripts/start-desktop.sh

    # Setup Moltbot
    /opt/coder-scripts/setup-moltbot.sh

    # Clone repo if provided
    if [ -n "${var.git_repo}" ] && [ ! -d ~/project ]; then
      git clone ${var.git_repo} ~/project
    fi
  EOT

  metadata {
    key          = "runtime"
    display_name = "Runtime"
    value        = "Moltbot + XFCE + Docker"
  }
}

resource "coder_app" "vnc" {
  agent_id     = coder_agent.main.id
  slug         = "vnc"
  display_name = "Desktop"
  icon         = "/icon/desktop.svg"
  url          = "http://localhost:6080/vnc.html"
  subdomain    = true
  share        = "authenticated"
}

resource "coder_app" "moltbot" {
  agent_id     = coder_agent.main.id
  slug         = "moltbot"
  display_name = "Moltbot"
  icon         = "/icon/terminal.svg"
  url          = "http://localhost:3000"
  subdomain    = true
  share        = "authenticated"
}
