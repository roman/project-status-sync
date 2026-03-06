{ lib, pkgs, ... }:

{
  git-hooks.hooks.cabal-test = lib.mapAttrs (_: lib.mkDefault) {
    name = "cabal-test";
    description = "Run cabal test suite";
    entry = "${pkgs.haskellPackages.cabal-install}/bin/cabal test";
    pass_filenames = false;
    always_run = true;
    stages = [ "pre-commit" ];
  };
}
