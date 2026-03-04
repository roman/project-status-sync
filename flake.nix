{
  description = "Claude Conversation Sync - cross-session context awareness";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-25.11";

    flake-parts.url = "github:hercules-ci/flake-parts";

    nixDir.url = "github:roman/nixDir/v3";
    nixDir.inputs.nixpkgs.follows = "nixpkgs";
    nixDir.inputs.devenv.follows = "devenv";

    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";

    systems.url = "github:nix-systems/default";

    bubblewrap-claude.url = "github:roman/bubblewrap-claude/feat/headless-mode";
    bubblewrap-claude.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      imports = [
        inputs.devenv.flakeModule
        inputs.nixDir.flakeModule
      ];

      nixDir = {
        enable = true;
        root = ./.;
        importWithInputs = true;
      };
    };
}
