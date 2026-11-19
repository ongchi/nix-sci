{
  description = "Nix packages of scientific codes: OpenGeoSys, open-DARTS, PFLOTRAN and ViTables";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # OpenGeoSys

        # PETSc decides the MPI and the (parallel) HDF5 build.
        # VTK, XDMF and OGS must link the same libraries.
        petsc = pkgs.petsc;
        mpi = petsc.petscPackages.mpi;
        hdf5 = petsc.petscPackages.hdf5;

        vtk = pkgs.vtk.override {
          mpiSupport = true;
          inherit mpi hdf5;
        };

        # OGS uses METIS with 64-bit indices (same as upstream CPM and Guix builds).
        metis = pkgs.metis.overrideAttrs (_old: {
          preConfigure = ''
            make config i64=1
          '';
        });

        # OGS enables Eigen's unsupported modules for Eigen > 3.4 and then
        # requires this commit (ogs.minimum_version.eigen-unsupported).
        eigen = pkgs.eigen.overrideAttrs (_old: {
          version = "3.4.90-unstable-2024-12-20";
          src = pkgs.fetchFromGitLab {
            owner = "libeigen";
            repo = "eigen";
            rev = "24e0c2a125d2b37b35719124d1f758777c150ca8";
            hash = "sha256-c0QHya0eDKQc5YvvxIoL722fPm3XD3PagJb+pEwSAGQ=";
          };
          # The nixpkgs patch only fixes a test and targets the 3.4.1 tag.
          patches = [ ];
        });

        iphreeqc = pkgs.callPackage ./pkgs/iphreeqc { };
        xmlpatch = pkgs.callPackage ./pkgs/xmlpatch { };
        xdmf = pkgs.callPackage ./pkgs/xdmf { inherit hdf5 mpi; };

        ogs = pkgs.callPackage ./pkgs/ogs {
          inherit petsc mpi hdf5 vtk metis eigen iphreeqc xmlpatch xdmf;
          tclap = pkgs.tclap_1_4;
        };

        # open-DARTS

        python3Packages = pkgs.python312Packages;

        hypre = pkgs.callPackage ./pkgs/hypre { };

        open-darts = pkgs.callPackage ./pkgs/open-darts {
          inherit python3Packages hypre;
        };

        open-darts-python = python3Packages.python.withPackages (ps: [
          open-darts
          ps.pyvista
        ]);

        # PFLOTRAN

        parmetis = pkgs.parmetis.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            sed -i 's/cmake_minimum_required(VERSION [0-9][^)]*)/cmake_minimum_required(VERSION 3.5)/' CMakeLists.txt
          '';
        });

        mkPetsc = { withParmetis ? false }:
          (pkgs.petsc.override ({
            withFullDeps = true;
            inherit withParmetis;
          } // pkgs.lib.optionalAttrs withParmetis {
            inherit parmetis;
          })).overrideAttrs (_old: {
            version = "3.24.3";
            src = pkgs.fetchzip {
              url = "https://web.cels.anl.gov/projects/petsc/download/release-snapshots/petsc-3.24.3.tar.gz";
              hash = "sha256-acrNcCTcjC4iLZD0lYvRhidnRTWsXs57XIQmZWKYIMg=";
            };
          });

        mkPflotran = { withParmetis ? false }:
          let petsc = mkPetsc { inherit withParmetis; };
          in import ./pkgs/pflotran { inherit system petsc withParmetis pkgs; inherit (pkgs) stdenv; };

        pflotran = mkPflotran { withParmetis = false; };

        # ViTables

        vitables = pkgs.callPackage ./pkgs/vitables { };
      in
      {
        packages = {
          inherit ogs vtk metis eigen iphreeqc xmlpatch xdmf;
          inherit open-darts hypre open-darts-python;
          inherit pflotran;
          inherit vitables;
        };

        devShells = {
          ogs = pkgs.mkShell {
            packages = [ ogs mpi ];
          };

          open-darts = pkgs.mkShell {
            packages = [ open-darts-python ];
          };

          pflotran = pkgs.mkShell {
            buildInputs = [
              pflotran.petsc
              pflotran.petsc.petscPackages.mpi
            ];
            shellHook = ''
              export PETSC_DIR=${pflotran.petsc}
              export PETSC_ARCH=${system}
            '';
            # export LDSHARED="$CC -bundle -undefined dynamic_lookup"
            # export PFLOTRAN_DIR=${pflotran}
            # export MPIEXEC=${mpi}/bin/mpiexec
          };
        };

        apps.vitables = flake-utils.lib.mkApp {
          drv = vitables;
        };
      }
    );
}
