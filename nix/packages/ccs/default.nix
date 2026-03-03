_flakeInputs:
{ haskellPackages }:

haskellPackages.callCabal2nix "ccs" ../../.. { }
