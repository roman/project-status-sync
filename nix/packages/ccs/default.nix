_flakeInputs:
{ haskellPackages }:

let
  pkg = haskellPackages.callCabal2nix "ccs" ../../.. { };
  prompts = ../../../prompts;
in
pkg.overrideAttrs (old: {
  postInstall = (old.postInstall or "") + ''
    mkdir -p $out/share/ccs/prompts
    cp ${prompts}/*.md $out/share/ccs/prompts/
  '';
})
