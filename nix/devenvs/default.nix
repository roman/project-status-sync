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
    hp.tasty
    hp.tasty-hunit
    hp.tasty-quickcheck
    hp.text
    hp.time
  ];
in
{
  imports = [
    inputs.nixDir.devenvModules.nixdir-skill
    inputs.self.devenvModules.session-tracking
    inputs.self.devenvModules.haskell-development-skill
    inputs.self.devenvModules.cabal-test
  ];

  # _module.args = { inherit inputs; };

  packages = [
    (pkgs.haskellPackages.ghcWithPackages haskellDeps)
    pkgs.haskellPackages.cabal-install
    pkgs.haskell-language-server
    inputs.bubblewrap-claude.packages.${pkgs.system}.claude-headless
  ];

  git-hooks.hooks.nixfmt = {
    enable = true;
    package = pkgs.nixfmt-rfc-style;
  };

  git-hooks.hooks.cabal-test.enable = true;

  claude.code.plugins.nixDir.enable = true;
  claude.code.plugins.haskell-development.enable = true;
}
