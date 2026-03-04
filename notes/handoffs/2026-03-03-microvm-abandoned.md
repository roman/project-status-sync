# MicroVM Sandbox Abandoned

**Date**: 2026-03-03
**Decision**: Abandon microvm.nix sandboxing approach

## Summary

After extensive experimentation, the microvm.nix approach for sandboxed
execution proved impractical due to fundamental architectural issues with
sharing the host's /nix/store.

## Issues Encountered

### 1. 9p Filesystem Performance
- 9p is notoriously slow for workloads with many small files
- Nix store access patterns (lots of stat/readdir/open) hit 9p's weaknesses
- Even with msize=100MB, per-operation latency dominated

### 2. virtiofs Complexity
- Requires virtiofsd daemon running on host before VM starts
- Needs user in `kvm` group with correct permissions
- Socket coordination between virtiofsd and QEMU
- microvm.nix host module required on NixOS host

### 3. Nix Database Mismatch
- /nix/var (containing SQLite db) on tmpfs, starts empty each boot
- Paths exist in shared store but aren't registered in VM's nix db
- Nix treats unregistered paths as missing, fetches from substituters
- Only the VM's system closure is registered via regInfo

### 4. nix-serve Performance
- Perl-based, single-threaded, compresses on-the-fly
- Even with localhost access, too slow for practical use
- Would need nix-serve-ng (Rust) for acceptable performance

### 5. Read-Only Store Conflicts
- Without writableStoreOverlay, store is read-only (squashfs)
- Can boot but can't install packages or run builds
- Overlay requires a shared "lower" layer

## Attempted Solutions

1. **9p overlay** — Too slow
2. **virtiofs overlay** — Complex setup, still had nix-db issues
3. **nix-serve only** — Removed overlay, but nix-serve too slow
4. **Standalone /nix volume** — Read-only conflicts, can't write to store

## Conclusion

The fundamental problem: microvm.nix assumes either a shared store (9p/virtiofs)
or a self-contained image. There's no clean way to have a writable, independent
store that's fast and doesn't require downloading everything.

Sandboxing via VMs is not worth the complexity for this project's use case.

## Files Removed

- `nix/configurations/nixos/claude-sandbox/` — VM configuration
- `scripts/run-sandbox.sh` — VM launch script
- `scripts/ralph-loop-sandboxed.sh` — Sandboxed ralph loop
- `microvm` flake input and related config
