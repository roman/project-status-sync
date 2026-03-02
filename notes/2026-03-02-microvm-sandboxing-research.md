# MicroVM Sandboxing for Ralph Loop

**Date**: 2026-03-02
**Status**: Research complete, ready for implementation
**References**:
- https://github.com/astro/microvm.nix
- ~/Projects/oss/microvm.nix (cloned)
- ~/Projects/oss/iidy-hs/scripts/ralph-loop.sh

## Problem Statement

The ralph loop uses `--dangerously-skip-permissions` to run Claude autonomously. This
grants the agent full access to:
- All files in `$HOME` (credentials, SSH keys, other projects)
- Host network (potential exfiltration)
- Host kernel (shared attack surface with containers)

iidy-hs mitigates via **instructional constraints** (CLAUDE.md safety rules) and
**tool whitelisting** (`--allowedTools`). These are trust-based, not enforced.

**Goal**: Enforce isolation technically, not just instructionally.

## Solution: MicroVM Sandboxing

Run each ralph loop session inside a lightweight NixOS VM. The agent can only access
what is explicitly shared.

### Why MicroVM over Containers?

| Property | Container (nix-shell, docker) | MicroVM |
|----------|-------------------------------|---------|
| Kernel | Shared with host | Separate |
| Escape difficulty | Kernel exploits possible | Hardware virtualization barrier |
| Filesystem isolation | Namespaces (bypassable) | Not mounted = not accessible |
| Network isolation | iptables/nftables | Hypervisor-level, user networking |
| Resource limits | cgroups (soft) | Hypervisor-enforced (hard) |
| Boot time | Instant | ~2-5 seconds |

MicroVM provides **defense in depth** — even if Claude finds an escape vector, it hits
the hypervisor barrier, not the host kernel.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│  HOST                                                                   │
│                                                                         │
│  ralph-loop-sandboxed.sh                                                │
│    │                                                                    │
│    │ starts VM per session                                              │
│    ▼                                                                    │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │  MICROVM: claude-sandbox                                          │ │
│  │                                                                    │ │
│  │  Mounts:                                                          │ │
│  │    /project (virtiofs, rw) → project directory on host            │ │
│  │    /nix/store (9p, ro)     → host nix store                       │ │
│  │                                                                    │ │
│  │  NOT mounted:                                                     │ │
│  │    ~/.ssh, ~/.aws, ~/.config, ~/.claude, other projects           │ │
│  │                                                                    │ │
│  │  Network:                                                         │ │
│  │    User networking (outbound only, no host access)                │ │
│  │    Allowlist: api.anthropic.com, ntfy.sh                          │ │
│  │                                                                    │ │
│  │  Lifecycle:                                                       │ │
│  │    Boot → run claude -p → exit → poweroff → VM destroyed          │ │
│  └───────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

## Security Properties

### What the Agent CAN Do (Intended)

- Read/write files in `/project` (the shared project directory)
- Make API calls to Claude API
- Send notifications to ntfy.sh
- Run builds via `nix build` (if writable store overlay configured)
- Commit to git (repo is in `/project`)

### What the Agent CANNOT Do (Enforced)

| Threat | Mitigation |
|--------|------------|
| Read `~/.ssh/id_rsa` | Not mounted |
| Read `~/.aws/credentials` | Not mounted |
| Access other projects | Not mounted |
| `rm -rf ~` | Only `/project` accessible |
| Kernel exploit | Separate kernel, hypervisor barrier |
| Persist malware | VM ephemeral, destroyed after session |
| Fork bomb | Resource limits enforced by hypervisor |
| Network exfiltration | User networking, outbound only |

## MicroVM Configuration

### Hypervisor Choice

**QEMU** recommended:
- Most featureful (9p + virtiofs shares)
- Well-tested on NixOS
- Supports control socket for clean shutdown

Alternatives:
- **cloud-hypervisor**: Faster boot, but no 9p shares
- **firecracker**: Minimal, but no filesystem shares (need block devices)

### Filesystem Sharing

**virtiofs** preferred over 9p:
- Better performance (~10 Gbps vs ~1.5 Gbps)
- More reliable for heavy I/O
- Requires virtiofsd service on host

**Shares needed**:

| Guest Path | Host Path | Proto | Mode | Purpose |
|------------|-----------|-------|------|---------|
| `/project` | Project dir | virtiofs | rw | Working directory |
| `/nix/.ro-store` | `/nix/store` | 9p | ro | Nix packages |

**Optional**: Writable nix store overlay for in-VM builds.

### Network Configuration

**User networking** (`type = "user"`):
- No setup required (no TAP devices)
- Outbound-only by default
- Guest cannot access host network directly
- SLIRP-based, ~100 Mbps sufficient for API calls

For stricter control, use TAP + nftables firewall rules.

### Resource Limits

```nix
microvm = {
  vcpu = 4;      # Enough for parallel tool calls
  mem = 4096;    # 4GB for claude context + tools
  # balloon = true;  # Optional: dynamic memory adjustment
};
```

## Implementation Plan

### Phase 1: Basic Sandboxed Session

1. Add microvm.nix input to flake.nix
2. Define `nixosConfigurations.claude-sandbox` with:
   - Minimal NixOS (no SSH, no extra services)
   - claude-code, git, coreutils in systemPackages
   - virtiofs share for project directory
   - 9p share for nix store (read-only)
   - User networking
3. Create `ralph-loop-sandboxed.sh` that:
   - Writes prompt to `.ralph-prompt`
   - Runs `nix run .#claude-sandbox`
   - Handles exit codes (restart/sleep/stop)
4. Test: Run one session, verify isolation

### Phase 2: Credential Handling

Problem: Claude needs API key, git needs author identity.

Options:
1. **Environment variable**: Pass `ANTHROPIC_API_KEY` in VM config
2. **Read-only credential file**: Mount single file, not whole directory
3. **Secret injection**: Use agenix to decrypt at VM boot

Recommendation: Option 2 — mount `~/.anthropic/api_key` read-only.

```nix
microvm.shares = [
  {
    proto = "9p";
    tag = "api-key";
    source = "/home/roman/.anthropic";
    mountPoint = "/run/secrets/anthropic";
  }
];
```

### Phase 3: Git Push Capability (Optional)

If agent needs to push commits:

Option A: Mount SSH key read-only
```nix
microvm.shares = [{
  proto = "9p";
  tag = "ssh";
  source = "/home/roman/.ssh";
  mountPoint = "/home/claude/.ssh";
}];
```

Option B: Use Git credential helper with limited token
- Create GitHub token with only repo:write scope
- Store in separate file, mount read-only

Option C: Agent commits locally, human pushes
- Safest — agent cannot push malicious code
- Human reviews before push

Recommendation: Start with Option C.

### Phase 4: Notification Integration

For ntfy.sh notifications from inside VM:
- User networking allows outbound HTTPS
- No special configuration needed
- Or mount ntfy credentials if using authenticated topics

## Open Questions

1. **Boot time**: Is 2-5 second overhead acceptable per session?
   - For long sessions (hours): negligible
   - For rapid iteration: may want persistent VM option

2. **Debugging**: How to inspect VM state when things go wrong?
   - Option: Add SSH temporarily for debugging
   - Option: Console access via qemu monitor
   - Option: Persistent VM mode (don't destroy after session)

3. **Nix builds inside VM**: Needed?
   - If yes: Configure writable store overlay (adds complexity)
   - If no: All builds happen on host before VM starts

4. **Multiple projects**: One VM definition per project, or parameterized?
   - Start with one (this project)
   - Generalize later if pattern works

## Reference: MicroVM Module Interface

Key options from microvm.nix:

```nix
microvm = {
  hypervisor = "qemu";           # qemu, cloud-hypervisor, firecracker, etc.
  vcpu = 1;                      # CPU cores
  mem = 512;                     # RAM in MB

  shares = [{                    # Filesystem shares
    proto = "virtiofs";          # or "9p"
    tag = "mytag";
    source = "/host/path";
    mountPoint = "/guest/path";
  }];

  volumes = [{                   # Block devices
    image = "state.img";
    mountPoint = "/var";
    size = 256;                  # MB
  }];

  interfaces = [{                # Networking
    type = "user";               # user, tap, bridge, macvtap
    id = "usernet";
  }];

  socket = "control.sock";       # For clean shutdown

  writableStoreOverlay = "/nix/.rw-store";  # Optional: in-VM nix builds
};
```

## Next Steps

1. [ ] Create `nix/microvm/claude-sandbox.nix` with VM definition
2. [ ] Add microvm.nix input to flake.nix
3. [ ] Create `scripts/ralph-loop-sandboxed.sh`
4. [ ] Test basic isolation (verify cannot access ~/.ssh)
5. [ ] Configure credential passing (API key)
6. [ ] Test full ralph loop cycle
7. [ ] Document in CLAUDE.md how to run sandboxed vs unsandboxed
