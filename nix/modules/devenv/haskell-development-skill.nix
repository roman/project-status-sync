{ pkgs, ... }:

{
  packages = [
    pkgs.haskellPackages.fourmolu
    pkgs.haskellPackages.hlint
  ];

  git-hooks.hooks = {
    fourmolu.enable = true;
    hlint.enable = true;
  };
}
