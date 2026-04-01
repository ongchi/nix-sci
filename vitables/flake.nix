{
  description = "ViTables — a viewer for HDF5 files";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        python = pkgs.python3;

        vitables = python.pkgs.buildPythonApplication {
          pname = "vitables";
          version = "3.1.0";

          src = pkgs.fetchFromGitHub {
            owner = "uvemas";
            repo = "ViTables";
            rev = "v3.1.0";
            hash = "sha256-+FNLz8IyMpfhsqnl1Z3RlGBrd2SGKfKiX/6UbSJmbxI=";
          };

          pyproject = true;

          build-system = [
            python.pkgs.hatchling
          ];

          dependencies = [
            python.pkgs.qtpy
            python.pkgs.tables
            python.pkgs.numpy
            python.pkgs.pyqt6
          ];

          # wrapQtAppsHook sets up Qt plugin paths; dontWrapQtApps + preFixup
          # ensures the Qt env vars are forwarded through the Python wrapper script.
          buildInputs = [
            pkgs.qt6.qtbase
          ];

          nativeBuildInputs = [
            pkgs.qt6.wrapQtAppsHook
          ];

          dontWrapQtApps = true;

          preFixup = ''
            makeWrapperArgs+=("''${qtWrapperArgs[@]}")
          '';

          meta = with pkgs.lib; {
            description = "A viewer for HDF5 files";
            longDescription = ''
              ViTables is a graphical tool for browsing and editing files in both
              HDF5 and PyTables formats. With ViTables you can display the object
              tree of any number of files, browse the content of tables and arrays,
              and edit attributes — all in an intuitive GUI built on Qt.
            '';
            homepage = "https://vitables.org";
            changelog = "https://github.com/uvemas/ViTables/releases";
            license = licenses.gpl3Plus;
            maintainers = [ ];
            platforms = platforms.unix;
            mainProgram = "vitables";
          };
        };
      in
      {
        packages = {
          default = vitables;
          vitables = vitables;
        };

        apps.default = flake-utils.lib.mkApp {
          drv = vitables;
        };
      }
    );
}
