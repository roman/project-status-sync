{
  description = "Claude Conversation Sync - cross-session context awareness";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-25.11";

    flake-parts.url = "github:hercules-ci/flake-parts";

    nixDir.url = "github:roman/nixDir/v3";
    nixDir.inputs.nixpkgs.follows = "nixpkgs";

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
        { pkgs, ... }:
        let
          haskellDeps = hp: [
            hp.aeson
            hp.bytestring
            hp.directory
            hp.filepath
            hp.optparse-applicative
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
        };
    };
}
