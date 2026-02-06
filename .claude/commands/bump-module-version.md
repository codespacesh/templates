# Bump Module Version

Bump the kubernetes-workspace module version after making changes.

## Steps

1. Get current version tag:
   ```bash
   git tag -l 'v*' | sort -V | tail -1
   ```

2. Determine next version (increment patch by default, or ask user for major/minor bump)

3. Create and push the new tag:
   ```bash
   git tag v<new_version> && git push --tags
   ```

4. Update all template module sources to use the new version:
   - `dind/module/main.tf`
   - `docker-compose/module/main.tf`
   - `openclaw/module/main.tf`

   Change `?ref=v<old>` to `?ref=v<new>` in each file's module "workspace" source.

5. Commit and push:
   ```bash
   git add -A && git commit -m "chore: bump module version to v<new_version>" && git push
   ```

6. Report the new version to the user.
