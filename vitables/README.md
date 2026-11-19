# nix-vitables

A Nix flake that packages [ViTables](https://vitables.org) — a graphical viewer for HDF5 and PyTables files.

## Usage

### Run without installing

```bash
nix run github:chii/nix-vitables
```

### Install into a profile

```bash
nix profile install github:chii/nix-vitables
vitables
```

### Use in another flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nix-vitables.url = "github:chii/nix-vitables";
  };

  outputs = { nixpkgs, nix-vitables, ... }: {
    # Access the package via:
    # nix-vitables.packages.${system}.default
  };
}
```

## Package details

| Field       | Value                              |
|-------------|------------------------------------|
| Version     | 3.1.0                              |
| License     | GPL-3.0-or-later                   |
| Upstream    | https://github.com/uvemas/ViTables |
| nixpkgs pin | nixos-25.11                        |

**Runtime dependencies:** `qtpy`, `PyTables`, `numpy`, `PyQt6`

## Building locally

```bash
git clone https://github.com/chii/nix-vitables
cd nix-vitables
nix build
./result/bin/vitables
```
