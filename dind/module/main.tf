# DinD Coder Template Module
# For projects that run services via docker-compose
# Uses the dind image (no Node/Bun runtime - services run in containers)

terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 2.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# =============================================================================
# VARIABLES - Passed from consuming project
# =============================================================================

variable "project_name" {
  type        = string
  description = "Project directory name in /home/coder"
}

variable "git_repo" {
  type        = string
  description = "Git repository URL"
}

variable "services" {
  type = map(object({
    port        = number
    public      = bool
    healthcheck = bool
  }))
  description = "Services to expose"
  default     = {}
}

variable "startup_hook" {
  type        = string
  description = "Path to startup script in repo"
  default     = ""
}

variable "install_command" {
  type        = string
  description = "Package manager install command (runs inside project dir)"
  default     = ""
}

variable "claude_code_oauth_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "dockerhub_username" {
  type      = string
  sensitive = true
  default   = ""
}

variable "dockerhub_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "git_setup_hook" {
  type        = string
  description = "Path to git setup script (runs before clone, for auth configuration)"
  default     = ""
}

variable "extra_env" {
  type        = map(string)
  description = "Additional environment variables to pass to the container"
  default     = {}
  sensitive   = true
}

# =============================================================================
# PROVIDERS
# =============================================================================

provider "docker" {}

provider "coder" {}

# =============================================================================
# CODER DATA SOURCES
# =============================================================================

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# =============================================================================
# PARAMETERS
# =============================================================================

data "coder_parameter" "git_repo" {
  name         = "git_repo"
  display_name = "Git Repository"
  default      = var.git_repo
  type         = "string"
  mutable      = false
}

data "coder_parameter" "issue_number" {
  name         = "issue_number"
  display_name = "Issue Number"
  description  = "GitHub issue number (optional)"
  default      = ""
  type         = "string"
  mutable      = true
}

data "coder_parameter" "issue_title" {
  name         = "issue_title"
  display_name = "Issue Title"
  default      = ""
  type         = "string"
  mutable      = true
}

data "coder_parameter" "issue_body" {
  name         = "issue_body"
  display_name = "Issue Body"
  default      = ""
  type         = "string"
  mutable      = true
}

data "coder_parameter" "issue_branch" {
  name         = "issue_branch"
  display_name = "Issue Branch"
  default      = ""
  type         = "string"
  mutable      = true
}

data "coder_parameter" "ai_prompt" {
  name         = "AI Prompt"
  display_name = "AI Prompt"
  description  = "AI prompt for workspace tasks"
  default      = data.coder_parameter.issue_number.value != "" ? "You are working on Issue #${data.coder_parameter.issue_number.value}: ${data.coder_parameter.issue_title.value}\n\nRequirements:\n${data.coder_parameter.issue_body.value}\n\nBranch: ${data.coder_parameter.issue_branch.value}" : "You are a helpful AI assistant for development."
  type         = "string"
  mutable      = true
}

# =============================================================================
# DOCKER RESOURCES
# =============================================================================

resource "docker_volume" "workspace" {
  name = "coder-${data.coder_workspace.me.id}"
  lifecycle {
    ignore_changes = all
  }
}

resource "docker_image" "workspace" {
  name          = "ghcr.io/codespacesh/dind:latest"
  pull_triggers = [timestamp()]
  keep_locally  = false
  force_remove  = true
}

resource "docker_container" "workspace" {
  count        = data.coder_workspace.me.start_count
  image        = docker_image.workspace.repo_digest
  name         = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  hostname     = data.coder_workspace.me.name
  runtime      = "sysbox-runc"
  stop_timeout = 300
  stop_signal  = "SIGKILL"

  env = concat([
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "CLAUDE_CODE_OAUTH_TOKEN=${var.claude_code_oauth_token}",
    "DOCKERHUB_USERNAME=${var.dockerhub_username}",
    "DOCKERHUB_TOKEN=${var.dockerhub_token}",
    "PROJECT_NAME=${var.project_name}",
    "GIT_REPO=${var.git_repo}",
    "INSTALL_COMMAND=${var.install_command}",
    "STARTUP_HOOK=${var.startup_hook}"
  ], [for k, v in var.extra_env : "${k}=${v}"])

  volumes {
    volume_name    = docker_volume.workspace.name
    container_path = "/home/coder"
  }

  command = ["sh", "-c", coder_agent.main.init_script]

  remove_volumes = true
  must_run       = false
  attach         = false
  logs           = false
  rm             = true

  lifecycle {
    ignore_changes = all
  }
}

# =============================================================================
# CODER AGENT
# =============================================================================

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"
  dir  = "/home/coder"

  env = {
    CODER_MCP_CLAUDE_TASK_PROMPT   = data.coder_parameter.ai_prompt.value
    CODER_MCP_APP_STATUS_SLUG      = "ccw"
    PATH                           = "/home/coder/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    CODER_MCP_CLAUDE_SYSTEM_PROMPT = "You are a helpful AI assistant for the ${var.project_name} development workspace."
    ISSUE_NUMBER                   = data.coder_parameter.issue_number.value
    ISSUE_TITLE                    = data.coder_parameter.issue_title.value
    ISSUE_BODY                     = data.coder_parameter.issue_body.value
    ISSUE_BRANCH                   = data.coder_parameter.issue_branch.value
    PROJECT_NAME                   = var.project_name
  }

  shutdown_script = <<-EOT
    #!/bin/bash
    echo "=== Shutdown ==="
    cd /home/coder/${var.project_name} 2>/dev/null && docker compose stop --timeout 10 2>/dev/null || true
    docker stop $(docker ps -q) 2>/dev/null || true
  EOT

  startup_script = <<-EOT
    #!/bin/bash
    set -e
    echo "=== Starting ${var.project_name} workspace ==="

    if ! command -v coder &> /dev/null; then
      curl -L https://coder.com/install.sh | sh
    fi

    export DOCKERHUB_USERNAME="${var.dockerhub_username}"
    export DOCKERHUB_TOKEN="${var.dockerhub_token}"
    export PROJECT_NAME="${var.project_name}"
    export CODER_WORKSPACE_NAME="${data.coder_workspace.me.name}"
    export CODER_USERNAME="${data.coder_workspace_owner.me.name}"
    export CODER_EMAIL="${data.coder_workspace_owner.me.email}"

    /opt/coder-scripts/setup-docker.sh
    /opt/coder-scripts/start-vnc.sh

    cd /home/coder

    # Run git setup hook if provided (for auth configuration)
    if [ -n "${var.git_setup_hook}" ]; then
      echo "Running git setup hook..."
      curl -fsSL "${var.git_setup_hook}" | bash
    fi

    if [ ! -d "/home/coder/${var.project_name}/.git" ]; then
      rm -rf "/home/coder/${var.project_name}"
      git clone "${var.git_repo}" "${var.project_name}"
    fi

    cd "/home/coder/${var.project_name}"

    git config --global credential.helper store
    git config --global user.name "$CODER_USERNAME"
    git config --global user.email "$CODER_EMAIL"

    if [ -n "$ISSUE_BRANCH" ]; then
      git fetch origin
      git checkout "$ISSUE_BRANCH" 2>/dev/null || git checkout -b "$ISSUE_BRANCH" origin/main 2>/dev/null || true
    fi

    # Run install command if provided
    if [ -n "${var.install_command}" ]; then
      ${var.install_command}
    fi

    [ -f .env.development ] && cp .env.development .env

    docker compose up -d

    if [ -n "${var.startup_hook}" ] && [ -f "${var.startup_hook}" ]; then
      echo "Running startup hook: ${var.startup_hook}"
      bash "${var.startup_hook}"
    fi

    echo "=== ${var.project_name} workspace ready ==="
    docker compose ps || true
  EOT
}

# =============================================================================
# SERVICE APPS
# =============================================================================

resource "coder_app" "services" {
  for_each = var.services

  agent_id     = coder_agent.main.id
  slug         = each.key
  display_name = title(each.key)
  url          = "http://localhost:${each.value.port}"
  icon         = "/icon/code.svg"
  subdomain    = true
  share        = each.value.public ? "public" : "authenticated"
  open_in      = each.key == "app" ? "tab" : "slim-window"

  dynamic "healthcheck" {
    for_each = each.value.healthcheck ? [1] : []
    content {
      url       = "http://localhost:${each.value.port}"
      interval  = 15
      threshold = 100
    }
  }
}

resource "coder_app" "vnc" {
  agent_id     = coder_agent.main.id
  slug         = "vnc"
  display_name = "VNC Desktop"
  url          = "http://localhost:6080/vnc.html?autoconnect=true"
  icon         = "/icon/desktop.svg"
  subdomain    = true
  share        = "authenticated"
}

# =============================================================================
# MODULES
# =============================================================================

module "code-server" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/code-server/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  folder   = "/home/coder/${var.project_name}"
}

module "claude-code" {
  count                   = data.coder_workspace.me.start_count
  source                  = "registry.coder.com/coder/claude-code/coder"
  version                 = "3.1.1"
  agent_id                = coder_agent.main.id
  workdir                 = "/home/coder/${var.project_name}"
  ai_prompt               = ""
  claude_code_oauth_token = var.claude_code_oauth_token
  install_claude_code     = true
  install_agentapi        = true
  report_tasks            = true
}

module "coder-login" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/coder-login/coder"
  version  = "1.1.0"
  agent_id = coder_agent.main.id
}

# =============================================================================
# METADATA
# =============================================================================

resource "coder_metadata" "workspace" {
  count       = data.coder_workspace.me.start_count
  resource_id = docker_container.workspace[0].id

  item {
    key   = "Runtime"
    value = "Sysbox DinD (Docker-in-Docker)"
  }

  item {
    key   = "Project"
    value = var.project_name
  }

  item {
    key   = "Repository"
    value = data.coder_parameter.git_repo.value
  }
}
