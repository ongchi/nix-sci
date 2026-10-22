{ lib
, stdenv
, fetchFromGitLab
, fetchFromGitHub
, cmake
, llvmPackages
, python3Packages
, hypre
, superlu
, withOpenMP ? true
}:

let
  # Sources of the open-DARTS v2.0.0 submodules that the CPU build needs.
  # HYPRE and SuperLU come as packages; AMGX (GPU) and IPhreeqc are not used.
  pybind11Src = fetchFromGitHub {
    owner = "pybind";
    repo = "pybind11";
    rev = "68322895df3d02c94deba6f3a3f531dd5b566cee";
    hash = "sha256-LNiwtFX+A9XwgW9ONNVhrVUFLNL09RRv+avWwcs4G5g=";
  };
  mshioSrc = fetchFromGitLab {
    owner = "open-darts";
    repo = "MshIO-fork";
    rev = "8d3254b0c4408f914f4074d0f4d9be5d8beff0a3";
    hash = "sha256-joEmIIpU8BjO7Lui/VTAwP2xA4wxI9xlQxdJ4AQtUVs=";
  };
in
python3Packages.buildPythonPackage rec {
  pname = "open-darts";
  version = "2.0.0";
  pyproject = true;

  src = fetchFromGitLab {
    owner = "open-darts";
    repo = "open-darts";
    tag = "v${version}";
    hash = "sha256-tEU/Jnwme0Ljg2T801ZKPlBacWCza2wl1eHIZbdwmnM=";
  };

  # Fixes for clang / libc++ on macOS (the upstream builds use GCC and MSVC):
  # compile errors
  #   - reading a static constexpr member through a reference parameter in a
  #     constant expression (allowed only from C++23, P2280)
  #   - an unqualified explicit instantiation outside its namespace
  #   - gslice_array -= gslice_array (libstdc++ extension); the right side now
  #     uses the const Matrix overload, which returns a valarray
  # import aborts
  #   - -Wl,-no_compact_unwind removed: without __unwind_info no C++ exception
  #     is caught (interpolators catch duplicate pybind11 registrations)
  #   - MechDiscretizer::n_unknowns read N_UNKNOWNS before its initialization
  #     (unordered template static member) and threw std::out_of_range
  # compiled linear solvers not loaded (silent fallback to a Python solver)
  #   - RPATH $ORIGIN -> @loader_path on Apple
  #   - libopendarts_linear_solvers.dylib added to the package data
  patches = [ ./macos.patch ];

  # pybind11 is added with add_subdirectory and writes its build tree next to
  # its sources, so it needs a writable copy in thirdparty/.
  postUnpack = ''
    rm -rf $sourceRoot/thirdparty/pybind11
    cp -r ${pybind11Src} $sourceRoot/thirdparty/pybind11
    chmod -R u+w $sourceRoot/thirdparty/pybind11
  '';

  build-system = [ python3Packages.setuptools ];

  nativeBuildInputs = [ cmake ];
  dontUseCmakeConfigure = true;

  buildInputs = [ hypre superlu ]
    ++ lib.optional (withOpenMP && stdenv.cc.isClang) llvmPackages.openmp;

  # CMake installs the compiled extensions into darts/ (CMAKE_INSTALL_PREFIX is
  # fixed to the source tree); setuptools then packs them as package data.
  preBuild = ''
    cmake -S . -B build \
      -DCMAKE_BUILD_TYPE=Release \
      -DOPENDARTS_CONFIG=${if withOpenMP then "MT" else "ST"} \
      -DPython_EXECUTABLE=${python3Packages.python.interpreter} \
      -DHYPRE_DIR=${hypre}/lib/cmake/HYPRE \
      -Dsuperlu_DIR=${superlu}/lib/cmake/superlu \
      -DMshIO_DIR=${mshioSrc}
    cmake --build build --target install --parallel $NIX_BUILD_CORES

    # Read by darts.print_build_info (normally written from git metadata)
    printf '%s\n' "nix build" "nix" "v${version}" > darts/build_info.txt
  '';

  dependencies = with python3Packages; [
    numba
    scipy
    pandas
    meshio
    gmsh
    iapws
    openpyxl
    pyevtk
    matplotlib
    shapely
    igraph
    sympy
    xarray
    netcdf4
    h5py
  ];

  # Not in nixpkgs. open-darts-flash: EoS physics only; opmcpg: CPG reservoir
  # only; phreeqpy: PHREEQC properties only.
  pythonRemoveDeps = [ "open-darts-flash" "opmcpg" "phreeqpy" ];
  pythonRelaxDeps = [ "pandas" "gmsh" "h5py" "netCDF4" ];

  pythonImportsCheck = [
    "darts.engines"
    "darts.discretizer"
    "darts.linear_solvers.linear_solvers"
    "darts.models.darts_model"
  ];

  passthru = { inherit hypre superlu; };

  meta = {
    description = "Open Delft Advanced Research Terra Simulator";
    homepage = "https://darts.citg.tudelft.nl";
    license = lib.licenses.gpl3Plus;
    mainProgram = "darts";
    platforms = lib.platforms.unix;
  };
}
