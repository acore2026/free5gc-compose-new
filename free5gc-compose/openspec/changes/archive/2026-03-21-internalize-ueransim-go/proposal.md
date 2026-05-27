## Why

The UERANSIM-Go source is currently located outside the project root (as a sibling directory), making the project non-portable and causing build failures if the external repository is missing or incorrectly placed. Moving it into `base/free5gc` as a nested repository (Git Submodule) consolidates the entire 5G stack (Core + RAN) into a single, self-contained unit.

## What Changes

- **Source Relocation**: Move `ueransim-go` from an external sibling path to `./base/free5gc/ueransim-go`.
- **Git Integration**: Add `ueransim-go` as a Git Submodule within the `base/free5gc` repository.
- **Orchestration Update**: Update `docker-compose-build.yaml` to use the new internal build context path (`./base/free5gc/ueransim-go`).
- **Dependency Management**: Ensure the project build process correctly handles the nested source structure.

## Capabilities

### New Capabilities
- `ran-source-internalization`: Consolidated management of RAN source code within the project tree for improved portability and version consistency.

### Modified Capabilities
- None.

## Impact

- **Build System**: The `docker-compose-build.yaml` file and any CI/CD pipelines must be updated to reference the new source path.
- **Repository Management**: Developers and users will need to use `--recursive` flags or `git submodule update` to fetch the full source tree.
- **Project Structure**: `base/free5gc/` will now contain the RAN source in addition to the Core NFs.
