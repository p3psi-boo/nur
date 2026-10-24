{
  lib,
  stdenv,
  generated,
  cmake,
  ninja,
  perl,
  pkg-config,
  makeWrapper,
  cacert,
  testers,
}:

let
  sourceInfo = generated.aria2-next;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "aria2-next";
  inherit (sourceInfo) src;
  version = lib.removePrefix "v" sourceInfo.version;

  nativeBuildInputs = [
    cmake
    ninja
    perl
    pkg-config
    makeWrapper
  ];

  # The supported upstream superbuild compiles the engine and its pinned
  # third_party sources offline; no release executables are downloaded.
  postPatch = ''
    patchShebangs third_party
    substituteInPlace cmake/superbuild/Dependencies.cmake \
      --replace-fail 'ProcessorCount(ARIA2_BUILD_JOBS)' \
        'set(ARIA2_BUILD_JOBS "$ENV{NIX_BUILD_CORES}")' \
      --replace-fail '-DCMAKE_POSITION_INDEPENDENT_CODE=ON)' \
        '-DCMAKE_POSITION_INDEPENDENT_CODE=ON -DCMAKE_INSTALL_LIBDIR=lib)'
  '';

  cmakeFlags = [
    "-GNinja"
    (lib.cmakeBool "ARIA2_SUPERBUILD" true)
    (lib.cmakeBool "BUILD_TESTING" true)
    (lib.cmakeBool "ARIA2_RELEASE_SIZE_OPTIMIZED" true)
  ];

  # Avoid multiplying outer and inner parallelism. Build dependencies one at
  # a time, giving each nested CMake/Make build the Nix core budget.
  buildPhase = ''
    runHook preBuild
    export CMAKE_BUILD_PARALLEL_LEVEL="$NIX_BUILD_CORES"
    cmake --build . --parallel 1
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ctest --output-on-failure --parallel "$NIX_BUILD_CORES"
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    cmake --install source --prefix "$out"
    install -Dm644 ../COPYING "$out/share/licenses/aria2-next/COPYING"
    runHook postInstall
  '';

  # The superbuild links vendored OpenSSL, whose default CA path is not a Nix path.
  # Keep explicit SSL_CERT_FILE overrides and --ca-certificate working.
  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    wrapProgram "$out/bin/aria2-next" \
      --set-default SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt"
  '';

  doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/aria2-next" --version | grep -F "${finalAttrs.version}"
    "$out/bin/aria2-next" --help > /dev/null
    runHook postInstallCheck
  '';

  passthru.tests = {
    version = testers.testVersion { package = finalAttrs.finalPackage; };
  };

  meta = {
    description = "Aria2-compatible download engine built on modern protocol libraries";
    homepage = "https://github.com/AnInsomniacy/aria2-next";
    changelog = "https://github.com/AnInsomniacy/aria2-next/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl2Plus;
    mainProgram = "aria2-next";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
})
