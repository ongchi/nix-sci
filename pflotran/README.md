# nix-pflotran

Nix flake for building [PFLOTRAN](https://www.pflotran.org), a massively parallel subsurface flow and reactive transport code.

## Packages

| Attribute | Description |
|-----------|-------------|
| `default` | PFLOTRAN built against PETSc 3.24.3 (without ParMETIS) |

## Usage

### Build

```sh
nix build
```

### Run

```sh
./result/bin/pflotran
```

### Development shell

Enters a shell with `PETSC_DIR` and `PETSC_ARCH` set, suitable for building PFLOTRAN manually:

```sh
nix develop
```

## Options

Both `mkPetsc` and `mkPflotran` accept a `withParmetis` flag (default `false`) to enable [ParMETIS](https://github.com/KarypisLab/ParMETIS) support for parallel graph partitioning.

```nix
# In your own flake
pflotran-with-parmetis = (nix-pflotran.packages.${system}.default.override or mkPflotran) { withParmetis = true; };
```

> **Note:** ParMETIS is an unfree package. Make sure `config.allowUnfree = true` is set in your nixpkgs configuration when enabling it.

## Requirements

- [Nix](https://nixos.org/download) with flakes enabled
- nixpkgs follows `nixos-25.11`
