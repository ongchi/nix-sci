# nix-open-darts

Nix flake for building [open-DARTS](https://darts.citg.tudelft.nl) 2.0.0 (Open Delft Advanced Research Terra Simulator).
PyPI has open-DARTS wheels only for Linux x86_64 and Windows; this flake builds it from source, also for macOS arm64.

## Packages

| Attribute    | Description |
|--------------|-------------|
| `default`    | Same as `open-darts` |
| `open-darts` | Python package `darts` (Python 3.12), multi-threaded (`OPENDARTS_CONFIG=MT`, OpenMP) |
| `hypre`      | HYPRE 3.1.0 at the commit pinned by open-DARTS (`341f908`), CMake build, OpenMP, no MPI |
| `python`     | Python 3.12 with `open-darts` and `pyvista` |

## Usage

### Build

```sh
nix build
```

### Development shell

Enters a shell with `python` that imports `darts`:

```sh
nix develop
python -c "import darts.engines"
```

From another project folder:

```sh
nix develop ~/Documents/Projects/Numerical/nix-open-darts
```

### Use in another flake

```nix
{
  inputs.nix-open-darts.url = "path:/path/to/nix-open-darts";

  outputs = { nixpkgs, nix-open-darts, ... }:
    let
      system = "aarch64-darwin";
      open-darts = nix-open-darts.packages.${system}.open-darts;
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ (pkgs.python312.withPackages (ps: [ open-darts ps.h5py ])) ];
      };
    };
}
```

Use the same Python version (3.12) as the flake; the compiled extensions are built for it.

## Options

`pkgs/open-darts` and `pkgs/hypre` accept `withOpenMP` (default `true`). With `false`, open-DARTS is built
single-threaded (`OPENDARTS_CONFIG=ST`) and HYPRE without OpenMP:

```nix
open-darts-st = nix-open-darts.packages.${system}.open-darts.override {
  withOpenMP = false;
  hypre = nix-open-darts.packages.${system}.hypre.override { withOpenMP = false; };
};
```

## Notes

- The upstream build script (`helper_scripts/build_darts_cmake.sh`) clones submodules and builds HYPRE and SuperLU
  into the source tree. Here HYPRE is the `hypre` package, SuperLU is nixpkgs `superlu` 7.0.1, and pybind11 and
  MshIO are fetched at the submodule commits of v2.0.0. AMGX (GPU) and IPhreeqc are not built.
- The nixpkgs `hypre` cannot be used: it is an autotools build with MPI and installs no CMake config package.
- CMake installs the compiled extensions into `darts/` of the source tree; setuptools then packs them.
- Python dependencies not in nixpkgs are removed: `open-darts-flash` (EoS physics), `opmcpg` (corner-point
  grids) and `phreeqpy` (PHREEQC properties). Models that use these modules fail at import.
- The pins `pandas==2.3.3`, `gmsh<=4.13`, `h5py==3.14.0` and `netCDF4==1.7.2` are relaxed to the nixpkgs versions.

## macOS patch (`pkgs/open-darts/macos.patch`)

Upstream builds and tests only with GCC (Linux) and MSVC (Windows). The patch fixes:

| Problem | Effect without the fix |
|---|---|
| `constexpr` read of a static member through a reference parameter (`approximation.h`) | Clang compile error (allowed only from C++23) |
| Unqualified explicit instantiation outside namespace `dis` (`mech_discretizer.cpp`) | Clang compile error |
| `gslice_array -= gslice_array` (`pm_discretizer.cpp`) | libc++ compile error (libstdc++ extension) |
| Linker flag `-Wl,-no_compact_unwind` | No `__unwind_info`: no C++ exception is caught; `import darts.engines` aborts |
| `MechDiscretizer::n_unknowns` reads the map `N_UNKNOWNS` during static initialization | `std::out_of_range` at load; `import darts.discretizer` aborts |
| RPATH `$ORIGIN` (Linux syntax) and `*.dylib` missing from the package data | The compiled linear solvers do not load; open-DARTS silently uses a fallback solver |

## Gmsh node-tag patch (`pkgs/open-darts/gmsh-node-tags.patch`, all platforms)

`Mesh::gmsh_mesh_reading` (C++ discretizer) stored the nodes in file order but used `node tag − 1` as the
index in the element node lists. For a `.msh` file whose node tags are not 1..N in file order, the elements got
wrong nodes, without an error. The patch stores each node at index `tag − 1` and stops with an error if the
node tags are not 1..N.

## Verification

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

## Requirements

- [Nix](https://nixos.org/download) with flakes enabled
- nixpkgs follows `nixos-25.11`
