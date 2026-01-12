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
# CONFIGURATION - Customize these for your project
# =============================================================================

locals {
  # Project settings
  project_name = "myproject"                                    # Directory name in /home/coder
  git_repo     = "https://git.noel.sh/myorg/myproject.git"     # Repository URL
  git_org      = "myorg"                                        # For registry auth

  # Services to expose (name => port)
  # These will be created as coder_app resources with healthchecks
  services = {
    app   = { port = 8081, public = true,  healthcheck = true }
    # zero  = { port = 4848, public = false, healthcheck = true }
    # minio = { port = 9201, public = false, healthcheck = false }
  }

  # Startup hook - path to custom script in your repo (relative to project root)
  # Set to "" to skip. Script will run after base setup completes.
  startup_hook = "scripts/coder/startup.sh"

  # Package manager command for installing dependencies
  install_command = "bun install"
}

# =============================================================================
# VARIABLES - Passed from Coder/environment
# =============================================================================

variable "gitea_token" {
  type        = string
  description = "Gitea token for registry and repo access"
  sensitive   = true
  default     = ""
}

variable "claude_code_oauth_token" {
  type        = string
  description = "Claude Code OAuth token for authentication"
  sensitive   = true
  default     = ""
}

variable "dockerhub_username" {
  type        = string
  sensitive   = true
  default     = ""
}

variable "dockerhub_token" {
  type        = string
  sensitive   = true
  default     = ""
}

# =============================================================================
# PROVIDERS
# =============================================================================

provider "docker" {
  registry_auth {
    address  = "git.noel.sh"
    username = "ci"
    password = var.gitea_token
  }
}

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
  default      = local.git_repo
  type         = "string"
  mutable      = false
}

data "coder_parameter" "issue_number" {
  name         = "issue_number"
  display_name = "Issue Number"
  description  = "Gitea issue number (optional)"
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
  name          = "git.noel.sh/codespacesh/docker-compose:latest"
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

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "GITEA_TOKEN=${var.gitea_token}",
    "CLAUDE_CODE_OAUTH_TOKEN=${var.claude_code_oauth_token}",
    "DOCKERHUB_USERNAME=${var.dockerhub_username}",
    "DOCKERHUB_TOKEN=${var.dockerhub_token}",
    "PROJECT_NAME=${local.project_name}",
    "GIT_REPO=${local.git_repo}",
    "INSTALL_COMMAND=${local.install_command}",
    "STARTUP_HOOK=${local.startup_hook}"
  ]

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
    PATH                           = "/home/coder/.bun/bin:/home/coder/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    CODER_MCP_CLAUDE_SYSTEM_PROMPT = "You are a helpful AI assistant for the ${local.project_name} development workspace."
    ISSUE_NUMBER                   = data.coder_parameter.issue_number.value
    ISSUE_TITLE                    = data.coder_parameter.issue_title.value
    ISSUE_BODY                     = data.coder_parameter.issue_body.value
    ISSUE_BRANCH                   = data.coder_parameter.issue_branch.value
    PROJECT_NAME                   = local.project_name
  }

  shutdown_script = <<-EOT
    #!/bin/bash
    echo "=== Shutdown ==="
    cd /home/coder/${local.project_name} 2>/dev/null && docker compose stop --timeout 10 2>/dev/null || true
    docker stop $(docker ps -q) 2>/dev/null || true
  EOT

  startup_script = <<-EOT
    #!/bin/bash
    set -e
    echo "=== Starting ${local.project_name} workspace ==="

    # Install Coder CLI if needed
    if ! command -v coder &> /dev/null; then
      curl -L https://coder.com/install.sh | sh
    fi

    # Export environment
    export GITEA_TOKEN="${var.gitea_token}"
    export DOCKERHUB_USERNAME="${var.dockerhub_username}"
    export DOCKERHUB_TOKEN="${var.dockerhub_token}"
    export PROJECT_NAME="${local.project_name}"
    export CODER_WORKSPACE_NAME="${data.coder_workspace.me.name}"
    export CODER_USERNAME="${data.coder_workspace_owner.me.name}"
    export CODER_EMAIL="${data.coder_workspace_owner.me.email}"

    # Run base setup scripts
    /opt/coder-scripts/setup-docker.sh
    /opt/coder-scripts/start-vnc.sh

    # Clone repository
    cd /home/coder
    if [ ! -d "/home/coder/${local.project_name}/.git" ]; then
      rm -rf "/home/coder/${local.project_name}"
      if [ -n "${var.gitea_token}" ]; then
        git clone "https://ci:${var.gitea_token}@git.noel.sh/${local.git_org}/${local.project_name}.git" "${local.project_name}"
      else
        git clone "${local.git_repo}" "${local.project_name}"
      fi
    fi

    cd "/home/coder/${local.project_name}"

    # Configure git
    git config --global credential.helper store
    git config --global user.name "$CODER_USERNAME"
    git config --global user.email "$CODER_EMAIL"

    # Checkout issue branch if specified
    if [ -n "$ISSUE_BRANCH" ]; then
      git fetch origin
      git checkout "$ISSUE_BRANCH" 2>/dev/null || git checkout -b "$ISSUE_BRANCH" origin/main 2>/dev/null || true
    fi

    # Install dependencies
    ${local.install_command}

    # Copy .env.development to .env if exists
    [ -f .env.development ] && cp .env.development .env

    # Start docker compose services
    docker compose up -d

    # Run custom startup hook if specified
    if [ -n "${local.startup_hook}" ] && [ -f "${local.startup_hook}" ]; then
      echo "Running startup hook: ${local.startup_hook}"
      bash "${local.startup_hook}"
    fi

    echo "=== ${local.project_name} workspace ready ==="
    docker compose ps || true
  EOT
}

# =============================================================================
# SERVICE APPS - Dynamically created from services map
# =============================================================================

resource "coder_app" "services" {
  for_each = local.services

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

# VNC Desktop (always included)
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
  folder   = "/home/coder/${local.project_name}"
}

module "claude-code" {
  count                   = data.coder_workspace.me.start_count
  source                  = "registry.coder.com/coder/claude-code/coder"
  version                 = "3.1.1"
  agent_id                = coder_agent.main.id
  workdir                 = "/home/coder/${local.project_name}"
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
    value = "Sysbox (Docker-in-Docker)"
  }

  item {
    key   = "Project"
    value = local.project_name
  }

  item {
    key   = "Repository"
    value = data.coder_parameter.git_repo.value
  }
}
