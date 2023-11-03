{
  description = "A `flake-parts` home-manager integration";
  output = { ... } : {
    flakeModule = ./nix/flake-module.nix;
  };
}
