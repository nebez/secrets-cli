# CLAUDE.md

## Build

```bash
make build
```

## Release

Versions follow semver (`vX.Y.Z`). To cut a new release:

1. Update the `version` constant in `secrets.swift` to match the new version (without the `v` prefix).

2. Build a clean binary:
   ```bash
   make clean && make build
   ```

3. Commit, tag, and push:
   ```bash
   git tag vX.Y.Z
   git push origin main vX.Y.Z
   ```

4. Create the GitHub release with the binary attached:
   ```bash
   gh release create vX.Y.Z ./secrets \
     --title "vX.Y.Z" \
     --verify-tag
   ```
