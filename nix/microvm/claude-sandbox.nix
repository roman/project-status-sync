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

    extraArgsScript = ''
      # Dynamic shares added at runtime by ralph-loop-sandboxed.sh
      # via MICROVM_EXTRA_ARGS environment variable
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

  fileSystems."/project" = {
    device = "project";
    fsType = "9p";
    options = [ "trans=virtio" "version=9p2000.L" "msize=104857600" ];
  };

  fileSystems."/home/claude/.gitconfig" = {
    device = "gitconfig";
    fsType = "9p";
    options = [ "trans=virtio" "version=9p2000.L" "ro" ];
  };

  fileSystems."/run/secrets/anthropic" = {
    device = "anthropic";
    fsType = "9p";
    options = [ "trans=virtio" "version=9p2000.L" "ro" ];
  };

  system.stateVersion = "25.11";
}
