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

    microvm.url = "github:astro/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";

    systems.url = "github:nix-systems/default";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      imports = [
        inputs.nixDir.flakeModule
      ];

      nixDir = {
        enable = true;
        root = ./.;
        importWithInputs = true;
      };

      perSystem =
        { pkgs, system, ... }:
        let
          haskellDeps = hp: [
            hp.aeson
            hp.bytestring
            hp.directory
            hp.filepath
            hp.optparse-applicative
            hp.tasty
            hp.tasty-hunit
            hp.text
            hp.time
          ];
        in
        {
          devShells.default = pkgs.mkShell {
            buildInputs = [
              (pkgs.haskellPackages.ghcWithPackages haskellDeps)
              pkgs.haskellPackages.cabal-install
              pkgs.haskell-language-server
            ];
          };

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
