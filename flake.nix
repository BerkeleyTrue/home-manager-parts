{
  description = "A `flake-parts` home-manager integration";
  outputs = {...}: {
    flakeModule = ./nix/flake-module.nix;
  };
}
