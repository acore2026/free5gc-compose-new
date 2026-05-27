## Context

The `free5gc-compose` project orchestrates a full 5G stack but currently relies on an external sibling directory for the RAN (`ueransim-go`). This setup prevents the root repository from being a complete, portable environment. The `base/free5gc` directory is already its own Git repository, providing a logical home for the RAN source code.

## Goals / Non-Goals

**Goals:**
- Consolidate all source code within the project root.
- Enable version-pinned synchronization between the Core (`free5gc`) and RAN (`ueransim-go`).
- Simplify the build orchestration by using internal paths.

**Non-Goals:**
- Modifying the internal logic of either `free5gc` or `ueransim-go`.
- Consolidation of the two Git repositories into one (nested repositories will be maintained).

## Decisions

### 1. Git Submodule for RAN Source
We will add `ueransim-go` as a Git Submodule inside the `base/free5gc` repository.
- **Rationale**: This allows `ueransim-go` to be developed independently while still being version-pinned to the `free5gc` core repository.
- **Alternative**: Git Subtree. Rejected because it merges histories and makes contributing back to the upstream RAN repo more complex.

### 2. Orchestration Path Mapping
The Root repo's `docker-compose-build.yaml` will be updated to point to the new internal path.
- **Old Path**: `../ueransim-go`
- **New Path**: `./base/free5gc/ueransim-go`
- **Rationale**: This path is relative to the Root repo and will be consistently available after a recursive clone.

## Risks / Trade-offs

- **[Submodule Complexity]** → Users cloning the Root repo must be aware of the nested structure. 
  - **Mitigation**: Update the project README and provide `make` targets to automate `git submodule update --init --recursive`.
- **[Build Context]** → If the Core repo (`base/free5gc`) is updated without updating the Root repo's submodule pointer, builds may use stale code.
  - **Mitigation**: Establish a convention of updating pointers in the Root repo whenever NFs or RAN versions are bumped.
