# Coder Templates

Reusable Coder workspace templates for different project types.

## Templates

| Template | Runtime | Use Case |
|----------|---------|----------|
| `base` | Ubuntu + Docker-in-Docker | Foundation for all templates |
| `bun-one` | Bun + One Framework | React Native/Web apps with Zero sync |
| `node-yarn` | Node.js + Yarn | Traditional Node.js projects |

## Usage

### 1. Reference in your project's `infra/coder/main.tf`:

```hcl
# For bun-one projects
resource "docker_image" "workspace" {
  name = "git.noel.sh/codespacesh/bun-one:latest"
}
```

### 2. Copy the template's `main.tf` and customize:

```hcl
# Customize these variables for your project
locals {
  project_name = "myproject"
  git_repo     = "https://git.noel.sh/myorg/myproject.git"
  app_port     = 8081
}
```

## Building Images

Images are automatically built and pushed to `git.noel.sh/codespacesh/` on push to main.

Manual build:
```bash
docker build -t git.noel.sh/codespacesh/base:latest -f base/Dockerfile .
docker build -t git.noel.sh/codespacesh/bun-one:latest -f bun-one/Dockerfile .
```

## Template Structure

```
templates/
├── base/                    # Shared base image
│   ├── Dockerfile
│   ├── docker-archive-keyring.gpg
│   ├── docker.list
│   └── scripts/             # Common setup scripts
├── bun-one/                 # Bun + One framework
│   ├── Dockerfile           # FROM base, adds bun
│   ├── main.tf              # Terraform template
│   └── scripts/             # Project-specific scripts
├── node-yarn/               # Node.js + Yarn
│   ├── Dockerfile
│   ├── main.tf
│   └── scripts/
└── .gitea/workflows/
    └── build-images.yaml
```

## Creating a New Template

1. Create a new directory: `mkdir mytemplate`
2. Create `Dockerfile` extending base: `FROM git.noel.sh/codespacesh/base:latest`
3. Add runtime-specific setup
4. Copy and customize `main.tf` from an existing template
5. Add to workflow for CI builds
