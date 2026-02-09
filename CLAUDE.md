# Claude Code Context

## Project Overview

Coder workspace templates for the Codespace.sh platform. These templates define development environments that run on Kubernetes with sysbox-runc for Docker-in-Docker support.

## Repository Structure

```
templates/
  base/              # Base image with common tools
  dind/              # Docker-in-Docker template
  docker-compose/    # Docker Compose development template
  openclaw/          # AI agent development template
  desktop/           # XFCE desktop environment
  modules/
    kubernetes-workspace/  # Shared Terraform module for K8s pods
  .github/workflows/
    build-images.yaml      # Builds and pushes Docker images to ghcr.io
```

## Image Hierarchy

```
base (git, common tools)
  └── dind (Docker, docker-compose)
        ├── docker-compose (bun, dev tools)
        └── desktop (XFCE, VNC)
              └── openclaw (Node.js, OpenClaw)
```

## Key Concepts

### Shared Module
All templates use a shared Terraform module at `modules/kubernetes-workspace/`. Templates reference it via git:

```terraform
module "workspace" {
  source = "git::https://github.com/codespacesh/templates.git//modules/kubernetes-workspace?ref=v1.0.0"
}
```

### Versioning
Module references use version tags (`?ref=v1.0.0`) to ensure controlled updates. When updating the shared module:

1. Make changes to `modules/kubernetes-workspace/`
2. Commit and push
3. Create new tag: `git tag v1.0.1 && git push --tags`
4. Update all templates to use new version
5. Push templates to Coder

### Custom Images
Templates support custom workspace images:

```terraform
module "workspace" {
  source = "git::https://github.com/codespacesh/templates.git//dind/module"

  image              = "ghcr.io/myorg/custom-image:latest"
  image_pull_secrets = ["my-registry-secret"]
  project_name       = "myproject"
  git_repo           = "https://github.com/myorg/myproject"
}
```

## Template Variables

All templates support:
- `image` - Custom container image (optional, has sensible default)
- `image_pull_secrets` - List of K8s secrets for private registries
- `namespace` - K8s namespace (auto-detected if empty)

Template-specific variables are documented in each template's main.tf.

## Default Images

| Template | Default Image |
|----------|---------------|
| dind | `ghcr.io/codespacesh/dind:latest` |
| docker-compose | `ghcr.io/codespacesh/docker-compose:latest` |
| openclaw | `ghcr.io/codespacesh/openclaw:latest` |

## Common Tasks

### Update Shared Module
```bash
# Edit modules/kubernetes-workspace/*.tf
git add -A && git commit -m "fix: description"
git push
# Then run: /bump-module-version
```

### Push Template to Coder
```bash
coder templates push <template-name> -d <template>/module
```

## GitHub Actions

The `build-images.yaml` workflow:
- On PR: Builds all images (no push) and runs verification
- On push to main: Builds and pushes to ghcr.io/codespacesh/*
