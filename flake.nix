{
  description = "A `flake-parts` home-manager integration";
  outputs = {...}: {
    flakeModule = ./home-manager-parts;
  };
}
