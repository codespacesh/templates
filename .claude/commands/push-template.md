# Push Template to Coder

Push a template to the Coder instance.

## Arguments
- `$ARGUMENTS` - Template name (dind, docker-compose, openclaw) or "all"

## Steps

1. If no argument provided, ask user which template to push

2. For each template to push:
   ```bash
   coder templates push <name> -d <name>/module -y
   ```

3. If "all" specified, push all templates:
   - dind
   - docker-compose
   - openclaw

4. Report success/failure for each template.
