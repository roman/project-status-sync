inputs:
{ pkgs, ... }:

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
  imports = [
    inputs.nixDir.devenvModules.nixdir-skill
    inputs.self.devenvModules.session-tracking
  ];

  packages = [
    (pkgs.haskellPackages.ghcWithPackages haskellDeps)
    pkgs.haskellPackages.cabal-install
    pkgs.haskell-language-server
    inputs.bubblewrap-claude.packages.${pkgs.system}.claude-headless
  ];

  claude.code.plugins.nixDir.enable = true;
}
