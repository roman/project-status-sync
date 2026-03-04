{
  description = "Claude Conversation Sync - cross-session context awareness";

  nixConfig = {
    extra-substituters = [ "https://microvm.cachix.org" ];
    extra-trusted-public-keys = [ "microvm.cachix.org-1:oXnBc6hRE3eX5rSYdRyMYXnfzcCxC7yKPTbZXALsqys=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-25.11";

    flake-parts.url = "github:hercules-ci/flake-parts";

    nixDir.url = "github:roman/nixDir/v3";
    nixDir.inputs.nixpkgs.follows = "nixpkgs";
    nixDir.inputs.devenv.follows = "devenv";

    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";

    microvm.url = "github:astro/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";

    systems.url = "github:nix-systems/default";
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

      perSystem =
        { ... }:
        {
          packages.claude-sandbox =
            inputs.self.nixosConfigurations.claude-sandbox.config.microvm.declaredRunner;
        };

      flake = {
        nixosConfigurations.claude-sandbox = inputs.nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            inputs.microvm.nixosModules.microvm
            ./nix/microvm/claude-sandbox.nix
          ];
        };
      };
    };
}
