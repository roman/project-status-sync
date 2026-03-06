inputs:
{ pkgs, ... }:

let
  haskellDeps = hp: [
    hp.aeson
    hp.aeson-qq
    hp.bytestring
    hp.directory
    hp.filepath
    hp.optparse-applicative
    hp.process
    hp.rio
    hp.tasty
    hp.tasty-hunit
    hp.tasty-quickcheck
    hp.text
    hp.time
  ];

  sandboxLib = inputs.bubblewrap-claude.lib.${pkgs.system};

  devTools = [
    (pkgs.haskellPackages.ghcWithPackages haskellDeps)
    pkgs.haskellPackages.cabal-install
    pkgs.haskell-language-server
    pkgs.haskellPackages.fourmolu
    pkgs.haskellPackages.hlint
    pkgs.nixfmt-rfc-style
  ];

  ccsHeadless = sandboxLib.mkHeadlessSandbox (
    sandboxLib.deriveProfile sandboxLib.base {
      name = "claude-headless-ccs";
      packages = devTools;
    }
  );
in
{
  imports = [
    inputs.nixDir.devenvModules.nixdir-skill
    inputs.self.devenvModules.session-tracking
    inputs.self.devenvModules.haskell-development-skill
    inputs.self.devenvModules.cabal-test
  ];

  packages = devTools ++ [ ccsHeadless ];

  git-hooks.hooks.nixfmt = {
    enable = true;
    package = pkgs.nixfmt-rfc-style;
  };

  git-hooks.hooks.cabal-test.enable = true;

  claude.code.plugins.nixDir.enable = true;
  claude.code.plugins.haskell-development.enable = true;
}
