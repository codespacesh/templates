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

## Architecture: Two-Layer System

Templates have two layers that update independently:

### Layer 1: Docker Images (scripts baked into container)
- Files in `<template>/scripts/` and `<template>/Dockerfile`
- Rebuilt by GitHub Actions on push to main (`build-images.yaml`)
- Changes take effect when a NEW workspace is created (or image is re-pulled with `imagePullPolicy: Always`)
- Example: `dind/scripts/setup-docker.sh`, `dind/scripts/start-vnc.sh`

### Layer 2: Terraform Templates (startup script, agent config)
- Files in `<template>/module/main.tf`
- Pushed to Coder via `coder templates push`
- Changes take effect after `coder update` + `coder restart`
- Example: `coder_agent.main.startup_script`, environment variables

### Key Insight
Each template defines its own `coder_agent` in `<template>/module/main.tf`. The shared `modules/kubernetes-workspace/` only handles K8s pod creation — it does NOT define the agent. So agent-level fixes (startup script, behavior settings) must be applied to each template individually.

## Common Tasks

### Update Shared Module
```bash
# Edit modules/kubernetes-workspace/*.tf
git add -A && git commit -m "fix: description"
git push
# Then run: /bump-module-version
```

### Push Template to Coder
Templates with required variables need `--variable` flags:
```bash
# Simple template (no required vars)
coder templates push <template-name> --directory <template>/module --yes

# Template with required variables (e.g., dind)
coder templates push dind --directory dind/module --yes \
  --variable git_repo="https://github.com/org/repo" \
  --variable project_name="myproject"
```

### Full Template Update Cycle
After editing `<template>/module/main.tf`:
```bash
# 1. Commit and push (triggers image rebuild if scripts changed)
git add -A && git commit -m "fix: description" && git push

# 2. Push template to Coder
coder templates push dind --directory dind/module --yes \
  --variable git_repo="https://github.com/coder/coder" \
  --variable project_name="coder"

# 3. Update workspace to use new template version
coder update admin/<workspace> --always-prompt=false

# 4. Restart workspace to apply changes
coder restart admin/<workspace> --yes

# 5. Verify
coder show admin/<workspace>  # Should show ⦿ connected ✔ healthy
```

**IMPORTANT:** `coder restart` alone does NOT pick up a new template version. You must `coder update` first, then restart.

## Template Debugging Workflow

### Check Workspace Status
```bash
coder show admin/<workspace>
# Look for: ⦿ connected ✔ healthy (good) vs ✘ agent startup script exited with an error (bad)
```

### Read Startup Script Logs
```bash
# Main startup script log
coder ssh admin/<workspace> -- 'cat /tmp/coder-startup-script.log'

# Filter for errors
coder ssh admin/<workspace> -- 'grep -E "(error|Error|WARNING|syntax)" /tmp/coder-startup-script.log'

# Other script logs
coder ssh admin/<workspace> -- 'ls /tmp/coder-script-*.log'
```

### Common Startup Script Errors

#### "syntax error near unexpected token `fi`"
**Cause:** Terraform variable interpolation produces empty bash blocks:
```bash
if [ -n "" ]; then
  # empty — bash syntax error
fi
```
**Fix:** Use Terraform-level conditionals instead of bash:
```hcl
%{ if var.some_var != "" }
${var.some_var}
%{ endif }
```

#### "output pipes were not closed after 10s"
**Cause:** Background processes (VNC, dockerd) inherit the startup script's stdout/stderr pipes. Coder waits for pipes to close and kills processes after 10s.
**Fix:** Two-part fix required:
1. Set `startup_script_behavior = "non-blocking"` on the `coder_agent` resource
2. Use `setsid` to fully detach background processes from the script's session:
```bash
setsid Xvfb :99 -screen 0 1920x1080x24 </dev/null >/dev/null 2>&1 &
```
Note: `>/dev/null 2>&1` alone is NOT sufficient — Coder captures output at process-level pipes that override shell redirects. `setsid` creates a new session that truly detaches.

#### "docker compose up -d" fails with no compose file
**Cause:** `set -e` is active and the repo has no docker-compose.yml.
**Fix:** Guard with file existence check:
```bash
if [ -f docker-compose.yml ] || [ -f docker-compose.yaml ] || [ -f compose.yml ] || [ -f compose.yaml ]; then
  docker compose up -d
fi
```

### Check Running Processes
```bash
coder ssh admin/<workspace> -- 'ps aux | grep -E "(Xvfb|x11vnc|fluxbox|websockify|dockerd)"'
coder ssh admin/<workspace> -- 'docker ps'
```

### Check Which Processes Hold Pipes
```bash
coder ssh admin/<workspace> -- 'for p in $(ls /proc/ | grep "^[0-9]*$"); do fd=$(readlink /proc/$p/fd/1 2>/dev/null); if echo "$fd" | grep -q "pipe:"; then cmd=$(cat /proc/$p/cmdline 2>/dev/null | tr "\0" " "); echo "PID $p ($fd): $cmd"; fi; done'
```

## Known Issues

### "Some workspace applications will not work" Warning
**Error:** `One or more apps in this workspace have subdomain = true, but subdomain applications are not configured.`
**Cause:** Coder server needs `--wildcard-access-url` to support subdomain-based app routing (e.g., code-server, VNC).
**Fix:** Configure the Coder server with a wildcard access URL:
```bash
# In Coder server config or deployment
--wildcard-access-url "*.coder.example.com"
```
See Coder docs on [wildcard access URL](https://coder.com/docs/admin/setup#wildcard-access-url) for setup with your DNS/ingress.

## GitHub Actions

The `build-images.yaml` workflow:
- On PR: Builds all images (no push) and runs verification
- On push to main: Builds and pushes to ghcr.io/codespacesh/*
- Images use the layer hierarchy (base → dind → docker-compose → desktop → openclaw)
- Script changes in `<template>/scripts/` are baked into the next image build
