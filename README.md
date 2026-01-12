# Coder Templates

Reusable Coder workspace templates for different project types.

## Templates

| Template | Runtime | Use Case |
|----------|---------|----------|
| `base` | Ubuntu + Docker-in-Docker | Foundation for all templates |
| `docker-compose` | Bun + Node.js | Projects using docker-compose |
| `node-yarn` | Node.js + Yarn | Traditional Node.js projects |

## Usage

### Use the Terraform Module

Reference the module in your project's `infra/coder/main.tf`:

```hcl
module "workspace" {
  source = "git::https://github.com/codespacesh/templates.git//docker-compose/module"

  project_name = "myproject"
  git_repo     = "https://github.com/myorg/myproject.git"

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
docker build -t ghcr.io/codespacesh/docker-compose:latest -f docker-compose/Dockerfile .
```

## Template Structure

```
templates/
├── base/                    # Shared base image
│   ├── Dockerfile
│   ├── docker-archive-keyring.gpg
│   ├── docker.list
│   └── scripts/             # Common setup scripts
├── docker-compose/          # Docker Compose template
│   ├── Dockerfile           # FROM base, adds bun + node
│   ├── module/              # Terraform module
│   │   └── main.tf
│   └── scripts/
├── node-yarn/               # Node.js + Yarn
│   ├── Dockerfile
│   └── scripts/
└── .github/workflows/
    └── build-images.yaml
```

## Creating a New Template

1. Create a new directory: `mkdir mytemplate`
2. Create `Dockerfile` extending base: `FROM ghcr.io/codespacesh/base:latest`
3. Add runtime-specific setup
4. Create `module/main.tf` with the Terraform module
5. Add to workflow for CI builds
