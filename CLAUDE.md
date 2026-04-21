# CLAUDE.md

## Build

```bash
make build
```

## Release

Versions follow semver (`vX.Y.Z`). To cut a new release:

1. Build a clean binary:
   ```bash
   make clean && make build
   ```

2. Tag the release:
   ```bash
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

3. Create the GitHub release with the binary attached:
   ```bash
   gh release create vX.Y.Z ./secrets \
     --title "vX.Y.Z" \
     --generate-notes \
     --verify-tag
   ```
