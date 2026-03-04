inputs: {
  system = "x86_64-linux";
  modules = [
    inputs.microvm.nixosModules.microvm
    ./configuration.nix
  ];
}
