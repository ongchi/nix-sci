{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        python3Packages = pkgs.python312Packages;

        hypre = pkgs.callPackage ./pkgs/hypre { };

        open-darts = pkgs.callPackage ./pkgs/open-darts {
          inherit python3Packages hypre;
        };

        python = python3Packages.python.withPackages (ps: [
          open-darts
          ps.pyvista
        ]);
      in
      {
        packages = {
          default = open-darts;
          inherit open-darts hypre python;
        };

        devShells.default = pkgs.mkShell {
          packages = [ python ];
        };
      }
    );
}
