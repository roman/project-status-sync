{ config, lib, pkgs, ... }:

{
  networking.hostName = "claude-sandbox";

  users.users.claude = {
    isNormalUser = true;
    home = "/home/claude";
    extraGroups = [ "wheel" ];
  };

  users.users.root.password = "";

  security.sudo.wheelNeedsPassword = false;

  # Enable poweroff/reboot
  services.logind.settings.Login.HandlePowerKey = "poweroff";

  environment.systemPackages = with pkgs; [
    git
    coreutils
    gnugrep
    gnused
    findutils
    which
    curl
  ];

  environment.variables = {
    HOME = "/home/claude";
  };

  # Enable flakes and nix-command
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Login message with instructions
  services.getty.helpLine = ''
    Claude Sandbox VM

    Mounts:
      /project     - shared project directory (if passed)
      /nix/.ro-store - host nix store (read-only)

    To exit: poweroff (or Ctrl-A X in QEMU)
  '';

  microvm = {
    hypervisor = "qemu";
    vcpu = 4;
    mem = 4096;

    shares = [
      {
        proto = "9p";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
    ];

    # Dynamic shares passed via MICROVM_EXTRA_ARGS by ralph-loop-sandboxed.sh
    # Format: -virtfs local,path=/path,mount_tag=project,security_model=mapped-xattr
    extraArgsScript = ''
      echo "''${MICROVM_EXTRA_ARGS:-}"
    '';

    interfaces = [
      {
        type = "user";
        id = "usernet";
        mac = "02:00:00:01:01:01";
      }
    ];

    socket = "claude-sandbox.sock";
  };

  # Optional mounts - only mount if the 9p tag exists
  # These are created by ralph-loop-sandboxed.sh via MICROVM_EXTRA_ARGS
  fileSystems."/project" = {
    device = "project";
    fsType = "9p";
    options = [ "trans=virtio" "version=9p2000.L" "msize=104857600" "nofail" "x-systemd.automount" ];
  };

  fileSystems."/home/claude/.gitconfig" = {
    device = "gitconfig";
    fsType = "9p";
    options = [ "trans=virtio" "version=9p2000.L" "ro" "nofail" "x-systemd.automount" ];
  };

  fileSystems."/run/secrets/anthropic" = {
    device = "anthropic";
    fsType = "9p";
    options = [ "trans=virtio" "version=9p2000.L" "ro" "nofail" "x-systemd.automount" ];
  };

  system.stateVersion = "25.11";
}
