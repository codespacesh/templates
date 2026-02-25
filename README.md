# Coder Templates

Reusable Coder workspace templates for different project types.

## Templates

| Template | Runtime | Use Case |
|----------|---------|----------|
| `base` | Ubuntu + Docker-in-Docker | Foundation for all templates |
| `dind` | Docker-in-Docker | General-purpose workspaces with Claude Code |
| `desktop` | XFCE + VNC | GUI desktop environment |
| `openclaw` | Node.js + AI tools | AI agent development |

## Usage

### Use the Terraform Module

Reference the module in your project's `infra/coder/main.tf`:

```hcl
module "workspace" {
  source = "git::https://github.com/codespacesh/templates.git//dind/module?ref=v1.1.12"

  project_name = "myproject"
  git_repos    = { "myproject" = "https://github.com/myorg/myproject.git" }

  services = {
    app   = { port = 8081, public = true, healthcheck = true }
    api   = { port = 3000, public = false, healthcheck = true }
  }

  startup_hook    = "scripts/startup.sh"
  install_command = "bun install"

  claude_code_oauth_token = var.claude_code_oauth_token
  dockerhub_username      = var.dockerhub_username
  dockerhub_token         = var.dockerhub_token
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
```

## Building Images

Images are automatically built and pushed to `ghcr.io/codespacesh/` on push to main via GitHub Actions.

Manual build:
```bash
docker build -t ghcr.io/codespacesh/base:latest -f base/Dockerfile .
docker build -t ghcr.io/codespacesh/dind:latest -f dind/Dockerfile .
```

## Template Structure

```
templates/
├── base/                    # Shared base image
│   ├── Dockerfile
│   ├── docker-archive-keyring.gpg
│   ├── docker.list
│   └── scripts/             # Common setup scripts
├── dind/                    # Docker-in-Docker template
│   ├── Dockerfile           # FROM base, adds Docker
│   ├── module/              # Terraform module
│   │   └── main.tf
│   └── scripts/             # setup-docker, start-vnc, etc.
├── desktop/                 # XFCE desktop environment
│   ├── Dockerfile           # FROM dind, adds XFCE + VNC
│   └── scripts/
├── openclaw/                # AI agent development
│   ├── Dockerfile           # FROM desktop, adds Node.js
│   ├── module/
│   │   └── main.tf
│   └── scripts/
└── .github/workflows/
    └── build-images.yaml
```

## Auto-Launch from GitHub Issues

Templates support auto-launching workspaces when a GitHub issue is labeled. The `dind` template includes built-in parameters for issue metadata (`issue_number`, `issue_title`, `issue_branch`, `ai_prompt`).

When an issue gets the `launch-codespace` label, a GitHub Action creates a Coder workspace with an AI agent that starts working on the issue automatically.

**Setup requires:**
1. A Coder API token stored as `CODER_TOKEN` GitHub secret
2. A `launch-codespace` label on the repo
3. A GitHub Action workflow that calls `coder create` with issue parameters
4. `.claude/settings.json` and `CLAUDE.md` for AI agent configuration

See the [example repo's setup guide](https://github.com/codespacesh/example/blob/main/docs/auto-launch-from-github-issues.md) for full instructions.

## Creating a New Template

1. Create a new directory: `mkdir mytemplate`
2. Create `Dockerfile` extending base: `FROM ghcr.io/codespacesh/base:latest`
3. Add runtime-specific setup
4. Create `module/main.tf` with the Terraform module
5. Add to workflow for CI builds
