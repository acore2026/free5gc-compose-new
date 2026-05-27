## ADDED Requirements

### Requirement: Internalized RAN source availability
The Root repository SHALL contain the RAN source code within its own directory structure, specifically at `./base/free5gc/ueransim-go`.

#### Scenario: Recursive clone or update
- **WHEN** a user runs `git clone --recursive` or `git submodule update --init --recursive`
- **THEN** the `ueransim-go` source code is populated within `./base/free5gc/ueransim-go`

### Requirement: Internalized build orchestration
The Root repository orchestration files (e.g., `docker-compose-build.yaml`) SHALL reference the internal RAN source path for image builds.

#### Scenario: Building from internal source
- **WHEN** a user runs `docker compose -f docker-compose-build.yaml build ueransim`
- **THEN** the build process uses the source code located at `./base/free5gc/ueransim-go`
