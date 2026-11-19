{ lib
, stdenv
, fetchFromGitHub
, cmake
, llvmPackages
, withOpenMP ? true
}:

# open-DARTS needs the HYPRE CMake config package (HYPRE::HYPRE) and a
# sequential (non-MPI) build. The nixpkgs hypre uses autotools with MPI.
stdenv.mkDerivation {
  pname = "hypre";
  version = "3.1.0-unstable-2026-05-08";

  # Commit pinned by the open-DARTS v2.0.0 submodule thirdparty/hypre
  src = fetchFromGitHub {
    owner = "hypre-space";
    repo = "hypre";
    rev = "341f9089807934407a52ea8324759f3af1e49a57";
    hash = "sha256-oTvd0nnlg1u+p83UfXl7ukDyoYKkco6zrmdjkJcSSWc=";
  };

  sourceRoot = "source/src";

  nativeBuildInputs = [ cmake ];

  buildInputs = lib.optional (withOpenMP && stdenv.cc.isClang) llvmPackages.openmp;

  # Same options as open-DARTS helper_scripts/build_darts_cmake.sh
  cmakeFlags = [
    "-DHYPRE_BUILD_TESTS=OFF"
    "-DHYPRE_BUILD_EXAMPLES=OFF"
    "-DHYPRE_ENABLE_MPI=OFF"
    "-DHYPRE_ENABLE_OPENMP=${if withOpenMP then "ON" else "OFF"}"
    "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
  ];

  meta = {
    description = "Sequential HYPRE (CMake build) as pinned by open-DARTS";
    homepage = "https://github.com/hypre-space/hypre";
    license = with lib.licenses; [ mit asl20 ];
    platforms = lib.platforms.unix;
  };
}
