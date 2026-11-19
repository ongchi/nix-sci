# nix-sci

Nix flake for scientific codes that nixpkgs does not have, or has without the needed options:

- [OpenGeoSys (OGS)](https://www.opengeosys.org) 6.5.9 with PETSc and MPI
- [open-DARTS](https://darts.citg.tudelft.nl) 2.0.0, also for macOS arm64
- [PFLOTRAN](https://www.pflotran.org) with PETSc 3.24.3
- [ViTables](https://vitables.org) 3.1.0, a viewer for HDF5 and PyTables files

All packages use one nixpkgs revision (`nixos-25.11`, see `flake.lock`).

## Packages

| Attribute           | Description |
|---------------------|-------------|
| `ogs`               | OGS CLI and utilities, built with `OGS_USE_PETSC=ON` against nixpkgs PETSc (OpenMPI) |
| `vtk`               | VTK with MPI support, sharing the MPI and parallel HDF5 of PETSc |
| `metis`             | METIS with 64-bit indices (provides `mpmetis` for `partmesh`) |
| `eigen`             | Eigen at commit `24e0c2a` (the version OGS pins for its unsupported modules) |
| `iphreeqc`          | IPhreeqc 3.5.0-4 (OGS fork) |
| `xmlpatch`          | xmlpatch 0.4.5 |
| `xdmf`              | XDMF 3.0.0 library |
| `open-darts`        | Python package `darts` (Python 3.12), multi-threaded (`OPENDARTS_CONFIG=MT`, OpenMP) |
| `hypre`             | HYPRE 3.1.0 at the commit pinned by open-DARTS (`341f908`), CMake build, OpenMP, no MPI |
| `open-darts-python` | Python 3.12 with `open-darts` and `pyvista` |
| `pflotran`          | PFLOTRAN built against PETSc 3.24.3 (without ParMETIS); its PETSc is `pflotran.petsc` |
| `vitables`          | ViTables 3.1.0, with a macOS `.app` bundle |

There is no `default` package. Development shells: `ogs`, `open-darts`, `pflotran`. App: `vitables`.

## Usage

```sh
nix build .#ogs
nix build .#open-darts
nix build .#pflotran
nix run .#vitables
nix develop .#ogs          # ogs, the OGS utilities and mpirun in PATH
nix develop .#open-darts   # python that imports darts
nix develop .#pflotran     # PETSC_DIR and PETSC_ARCH set, for a manual PFLOTRAN build
```

From another folder, use `github:ongchi/nix-sci#<attribute>` or `path:/path/to/nix-sci#<attribute>`.

### Install with nix-darwin (or NixOS / home-manager)

```nix
{
  inputs = {
    nix-sci.url = "github:ongchi/nix-sci";
    # Do not add `nix-sci.inputs.nixpkgs.follows = "nixpkgs"` unless you accept
    # a full rebuild of PETSc, VTK, OGS and open-DARTS against your nixpkgs.
  };

  outputs = { nix-darwin, nix-sci, ... }: {
    darwinConfigurations.<host> = nix-darwin.lib.darwinSystem {
      modules = [
        ({ pkgs, ... }:
          let
            sci = nix-sci.packages.${pkgs.stdenv.hostPlatform.system};
          in
          {
            environment.systemPackages = [
              sci.ogs      # ogs, partmesh, mpmetis and the other OGS utilities
              sci.ogs.mpi  # mpirun from the same OpenMPI that ogs links
              sci.pflotran
              sci.vitables
            ];
          })
      ];
    };
  };
}
```

## OGS

The prebuilt `ogs` wheel from PyPI is serial only; this build runs in parallel with `mpirun`.
The first build compiles VTK with MPI, which is not in the binary cache.

### Run in parallel

A parallel run needs a mesh partitioned into as many parts as MPI ranks:

```sh
# Convert the mesh to METIS input, partition it, and write the OGS binary partition files
partmesh -s -i mesh.vtu -o partitioned/
partmesh -m -n 4 -i mesh.vtu -o partitioned/ -- boundary1.vtu boundary2.vtu

# Run with 4 MPI ranks
mpirun -np 4 ogs project.prj -o out/
```

The project file must configure a `<petsc>` linear solver.

The `ogs` output does not contain `mpirun`. Use the `mpirun` of the OpenMPI that `ogs` links, which is
available as the `mpi` attribute of the package (`ogs.mpi`), for example through the development shell.
Do not use an `mpirun` from another OpenMPI version; OpenMPI 5 requires matching `mpirun` and `libmpi` versions.

### OGS and PFLOTRAN together

With the one nixpkgs revision of this flake, `ogs.mpi` and the MPI of the PFLOTRAN PETSc
(`pflotran.petsc.petscPackages.mpi`) are the same store path (OpenMPI 5.0.9; checked on aarch64-darwin).
Thus one `mpirun` (`ogs.mpi`) serves both programs:

```sh
mpirun -np 4 ogs project.prj -o out/
mpirun -np 4 pflotran -pflotranin input.in
```

After a change of `flake.lock` or of the PETSc of PFLOTRAN, check this again:

```sh
nix eval --raw .#ogs.mpi.outPath
nix eval --raw .#pflotran.petsc.petscPackages.mpi.outPath
```

Do not put two different OpenMPI packages in `environment.systemPackages`: they collide on `bin/mpirun`.

### Notes

- The OGS build system downloads its dependencies with CPM by default. Inside the Nix sandbox, OGS detects
  `NIX_BUILD_TOP` and switches to its offline "Guix build" mode, which uses `find_package()` for all dependencies.
- PETSc, VTK, XDMF and OGS link one MPI and one parallel HDF5 build.
- OGS requires TCLAP 1.4 (`pkgs.tclap_1_4`) and the pinned Eigen commit; the nixpkgs defaults are too old.
- OGS is configured out of source (`$NIX_BUILD_TOP/build`), because its header file sets reject a build
  directory nested inside the source directory.
- PETSc prints `Option left: name:-o` at the end of a run. This is harmless: OGS forwards its own command line to PETSc.
- Disabled features: MFront (TFEL is not in nixpkgs), NetCDF, the Python module, the Data Explorer GUI and the tests.

## open-DARTS

PyPI has open-DARTS wheels only for Linux x86_64 and Windows; this flake builds it from source, also for macOS arm64.

```sh
nix develop .#open-darts
python -c "import darts.engines"
```

### Use in another flake

```nix
{
  inputs.nix-sci.url = "github:ongchi/nix-sci";

  outputs = { nixpkgs, nix-sci, ... }:
    let
      system = "aarch64-darwin";
      open-darts = nix-sci.packages.${system}.open-darts;
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ (pkgs.python312.withPackages (ps: [ open-darts ps.h5py ])) ];
      };
    };
}
```

Use the same Python version (3.12) as the flake; the compiled extensions are built for it.

### Options

`pkgs/open-darts` and `pkgs/hypre` accept `withOpenMP` (default `true`). With `false`, open-DARTS is built
single-threaded (`OPENDARTS_CONFIG=ST`) and HYPRE without OpenMP:

```nix
open-darts-st = nix-sci.packages.${system}.open-darts.override {
  withOpenMP = false;
  hypre = nix-sci.packages.${system}.hypre.override { withOpenMP = false; };
};
```

### Notes

- The upstream build script (`helper_scripts/build_darts_cmake.sh`) clones submodules and builds HYPRE and SuperLU
  into the source tree. Here HYPRE is the `hypre` package, SuperLU is nixpkgs `superlu` 7.0.1, and pybind11 and
  MshIO are fetched at the submodule commits of v2.0.0. AMGX (GPU) and IPhreeqc are not built.
- The nixpkgs `hypre` cannot be used: it is an autotools build with MPI and installs no CMake config package.
- CMake installs the compiled extensions into `darts/` of the source tree; setuptools then packs them.
- Python dependencies not in nixpkgs are removed: `open-darts-flash` (EoS physics), `opmcpg` (corner-point
  grids) and `phreeqpy` (PHREEQC properties). Models that use these modules fail at import.
- The pins `pandas==2.3.3`, `gmsh<=4.13`, `h5py==3.14.0` and `netCDF4==1.7.2` are relaxed to the nixpkgs versions.

### macOS patch (`pkgs/open-darts/macos.patch`)

Upstream builds and tests only with GCC (Linux) and MSVC (Windows). The patch fixes:

| Problem | Effect without the fix |
|---|---|
| `constexpr` read of a static member through a reference parameter (`approximation.h`) | Clang compile error (allowed only from C++23) |
| Unqualified explicit instantiation outside namespace `dis` (`mech_discretizer.cpp`) | Clang compile error |
| `gslice_array -= gslice_array` (`pm_discretizer.cpp`) | libc++ compile error (libstdc++ extension) |
| Linker flag `-Wl,-no_compact_unwind` | No `__unwind_info`: no C++ exception is caught; `import darts.engines` aborts |
| `MechDiscretizer::n_unknowns` reads the map `N_UNKNOWNS` during static initialization | `std::out_of_range` at load; `import darts.discretizer` aborts |
| RPATH `$ORIGIN` (Linux syntax) and `*.dylib` missing from the package data | The compiled linear solvers do not load; open-DARTS silently uses a fallback solver |

### Gmsh node-tag patch (`pkgs/open-darts/gmsh-node-tags.patch`, all platforms)

`Mesh::gmsh_mesh_reading` (C++ discretizer) stored the nodes in file order but used `node tag − 1` as the
index in the element node lists. For a `.msh` file whose node tags are not 1..N in file order, the elements got
wrong nodes, without an error. The patch stores each node at index `tag − 1` and stops with an error if the
node tags are not 1..N.

### Verification

Upstream suite models (`models/run_test_suite2.py`, `check_performance`) against the Linux reference
`ref/perf_lin_odls.pkl`, on macOS arm64:

| Model | Threads | Steps / Newton / linear | Max. difference of the solution |
|---|---|---|---|
| `2ph_do` (TPFA) | default (MT) | 68 / 89 / 245, equal to the reference | 1e-12 |
| `2ph_do_thermal_mpfa` (unstructured Gmsh mesh, MPFA) | 1 | 215 / 735 / 7507, equal to the reference | 3e-12 |
| `2ph_do_thermal_mpfa` | default (MT) | 215 / 215 / 662 | **wrong** (up to 99 % in composition) |

**Run MPFA models with one thread** (`OMP_NUM_THREADS=1` or `darts.engines.set_num_threads(1)`). The upstream
`main.py` of this model does the same ("MPFA tests are not working in the multithread version yet").
TPFA models give the reference result with several threads.

## PFLOTRAN

```sh
nix build .#pflotran
./result/bin/pflotran -pflotranin input.in
```

### Options

`mkPetsc` and `mkPflotran` in `flake.nix` accept a `withParmetis` flag (default `false`) to enable
[ParMETIS](https://github.com/KarypisLab/ParMETIS) support for parallel graph partitioning.

> **Note:** ParMETIS is an unfree package. Set `config.allowUnfree = true` in the nixpkgs configuration of
> `flake.nix` when you enable it.

`pkgs/petsc` and `pkgs/lagrit` are not used by the flake.

## ViTables

```sh
nix run github:ongchi/nix-sci#vitables
nix profile install github:ongchi/nix-sci#vitables
```

The light color scheme is forced. On macOS the package also has `Applications/ViTables.app`.
Runtime dependencies: `qtpy`, `PyTables`, `numpy`, `PyQt6`. License: GPL-3.0-or-later.

## Requirements

- [Nix](https://nixos.org/download) with flakes enabled
