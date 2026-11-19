{ lib
, python3
, fetchFromGitHub
, qt6
}:

python3.pkgs.buildPythonApplication {
  pname = "vitables";
  version = "3.1.0";

  src = fetchFromGitHub {
    owner = "uvemas";
    repo = "ViTables";
    rev = "v3.1.0";
    hash = "sha256-+FNLz8IyMpfhsqnl1Z3RlGBrd2SGKfKiX/6UbSJmbxI=";
  };

  pyproject = true;

  build-system = [
    python3.pkgs.hatchling
  ];

  dependencies = [
    python3.pkgs.qtpy
    python3.pkgs.tables
    python3.pkgs.numpy
    python3.pkgs.pyqt6
  ];

  # wrapQtAppsHook sets up Qt plugin paths; dontWrapQtApps + preFixup
  # ensures the Qt env vars are forwarded through the Python wrapper script.
  buildInputs = [
    qt6.qtbase
  ];

  nativeBuildInputs = [
    qt6.wrapQtAppsHook
  ];

  dontWrapQtApps = true;

  preFixup = ''
    makeWrapperArgs+=("''${qtWrapperArgs[@]}")
  '';

  postPatch = ''
    sed -i '/    app = QtWidgets.QApplication(sys.argv)/a\    app.styleHints().setColorScheme(QtCore.Qt.ColorScheme.Light)' \
      vitables/start.py
  '';

  postInstall = ''
    mkdir -p $out/Applications/ViTables.app/Contents/MacOS
    {
      echo '<?xml version="1.0" encoding="UTF-8"?>'
      echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
      echo '<plist version="1.0"><dict>'
      echo '<key>CFBundleExecutable</key><string>vitables</string>'
      echo '<key>CFBundleIdentifier</key><string>org.vitables.ViTables</string>'
      echo '<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>'
      echo '<key>CFBundleName</key><string>ViTables</string>'
      echo '<key>CFBundlePackageType</key><string>APPL</string>'
      echo '<key>CFBundleShortVersionString</key><string>3.1.0</string>'
      echo '<key>CFBundleVersion</key><string>3.1.0</string>'
      echo '<key>NSHighResolutionCapable</key><true/>'
      echo '<key>NSRequiresAquaSystemAppearance</key><true/>'
      echo '</dict></plist>'
    } > $out/Applications/ViTables.app/Contents/Info.plist
    ln -s ../../../../bin/vitables $out/Applications/ViTables.app/Contents/MacOS/vitables
  '';

  meta = with lib; {
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
}
