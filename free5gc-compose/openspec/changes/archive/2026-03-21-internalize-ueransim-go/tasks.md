## 1. Repository Restructuring

- [x] 1.1 Add `ueransim-go` as a git submodule inside `base/free5gc` pointing to its remote repository
- [x] 1.2 Verify the submodule is correctly initialized and populated at `./base/free5gc/ueransim-go`

## 2. Build Orchestration Update

- [x] 2.1 Update `docker-compose-build.yaml` build context for `ueransim` service to `./base/free5gc/ueransim-go`
- [x] 2.2 Update `docker-compose-build.yaml` build context for `ue` service to `./base/free5gc/ueransim-go`
- [x] 2.3 Verify `docker compose -f docker-compose-build.yaml build ueransim ue` succeeds using the new paths

## 3. Documentation and Helpers

- [x] 3.1 Update README.md with instructions for recursive cloning and submodule initialization
- [x] 3.2 (Optional) Add a `make setup` or similar target to the root `Makefile` to automate `git submodule update --init --recursive`
