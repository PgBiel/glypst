{
  description = "A flake for glypst development";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { nixpkgs, flake-utils, ... }: flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
    in
    {
      formatter = pkgs.nixpkgs-fmt;

      devShells.default = pkgs.mkShell {
        nativeBuildInputs = [
          pkgs.gleam
          pkgs.erlang
          pkgs.typst
        ];
      };
    });
}
