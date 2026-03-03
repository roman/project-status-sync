# MicroVM Nix Store Caching Issue

**Date**: 2026-03-03
**Status**: Deferred — VM works for ralph loop, nix commands are slow
**Blocking**: Nothing critical (ralph loop doesn't need nix commands in VM)

## Problem

The VM shares the host's `/nix/store` via 9p mount at `/nix/.ro-store`, with a writable
overlay at `/nix/.rw-store`. The overlayfs makes host paths accessible at `/nix/store`.

However, **nix commands don't use the cached paths** — they download from cache.nixos.org:

```
[claude@claude-sandbox:/project]$ nix flake show
[1/0/1 copied (0.0/185.7 MiB), 2.7/31.9 MiB DL] fetching source from https://cache.nixos.org
```

## Root Cause

The nix daemon uses a SQLite database (`/nix/var/nix/db/db.sqlite`) to track known store
paths. The VM's database is empty — it doesn't know the host's paths exist, even though
they're mounted via overlayfs.

Nix checks the database before looking at the filesystem. No database entry = path doesn't
exist = download from substituter.

## Current Configuration

```nix
microvm = {
  shares = [{
    proto = "9p";
    tag = "ro-store";
    source = "/nix/store";
    mountPoint = "/nix/.ro-store";
  }];
  writableStoreOverlay = "/nix/.rw-store";
  volumes = [{
    image = "nix-store-overlay.img";
    mountPoint = "/nix/.rw-store";
    size = 2048;
  }];
};

fileSystems."/nix/var" = {
  device = "none";
  fsType = "tmpfs";
  options = [ "mode=0755" "size=1G" ];
};
```

## Potential Solutions

### Option 1: Register paths on boot (Recommended)

Run `nix-store --register-validity` with path info from host on VM boot.

**Approach**:
1. On host: `nix path-info --recursive --json /nix/store/... > closure.json`
2. Share closure.json with VM via 9p
3. On VM boot: systemd service parses JSON, registers paths in VM's nix db

**Pros**: Paths are known to nix, no downloads
**Cons**: Need to regenerate closure.json when host store changes

**Implementation sketch**:
```nix
# In ralph-loop-sandboxed.sh, before starting VM:
nix path-info --recursive --json $(nix build .#claude-sandbox --print-out-paths) \
  > /tmp/vm-closure.json

# Share /tmp/vm-closure.json via 9p mount

# In VM, systemd oneshot service:
nix-store --load-db < /path/to/closure.json
```

### Option 2: Share host's nix database (read-only)

Mount `/nix/var/nix/db` from host as read-only.

**Pros**: All host paths immediately known
**Cons**:
- DB is locked by host's nix-daemon
- May cause conflicts with VM's nix-daemon
- Security concern (leaks host store info)

### Option 3: Use nix-serve as local substituter

Run nix-serve on host, configure VM to use it.

**Approach**:
1. Host runs `nix-serve -p 5000`
2. VM configured with `substituters = http://host:5000`
3. VM fetches from host over network instead of internet

**Pros**: Works with existing nix infrastructure
**Cons**: Requires network setup, another service to manage

### Option 4: Accept slow first run, persist overlay

Keep the current setup. First run downloads, subsequent runs use cached overlay.

**Pros**: Simple, no changes needed
**Cons**: First run is slow, overlay image grows

## Recommendation

For ralph loop use case: **No action needed**. The VM doesn't need to run nix commands —
it runs `claude-code` and `git`, which are already in the VM's closure.

If nix commands become necessary:
1. Start with Option 4 (accept slow, persist overlay)
2. If too painful, implement Option 1 (register paths on boot)

## Files to Modify (if implementing Option 1)

| File | Change |
|------|--------|
| `scripts/run-sandbox.sh` | Generate closure.json before VM start |
| `scripts/ralph-loop-sandboxed.sh` | Generate closure.json before VM start |
| `nix/microvm/claude-sandbox.nix` | Add 9p share for closure.json, systemd service to register |

## References

- microvm.nix store handling: `~/Projects/oss/microvm.nix/nixos-modules/microvm/store-disk.nix`
- nix-store --load-db: `man nix-store`
- nix path-info: `man nix3-path-info`
