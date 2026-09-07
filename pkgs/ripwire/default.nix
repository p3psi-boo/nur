{
  lib,
  stdenv,
  cmake,
  ninja,
  generated,
}:

let
  sourceInfo = generated.ripwire;
in
stdenv.mkDerivation {
  pname = "ripwire";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  nativeBuildInputs = [
    cmake
    ninja
  ];

  cmakeFlags = [
    "-DRIPWIRE_NATIVE=OFF"
    "-DRIPWIRE_TESTS=OFF"
  ];

  # serialize.h uses snprintf(buf, n, fmt, args...) with a lambda fmt parameter;
  # gcc 15 -Werror=format-security rejects that when args is empty.
  hardeningDisable = [ "format" ];

  # cmakeInstallFlags --component is not reliably passed through the cmake hook.
  # Drop the vendored tree-sitter headers/pkgconfig that leak into $out.
  postInstall = ''
    rm -rf "$out/lib" "$out/include"
  '';

  # RIPWIRE_TESTS=ON fails to compile verify_pagerank.cpp against pageRankDouble's
  # current return type (PageRankRun vs unsigned).
  doCheck = false;

  meta = {
    description = "Zero-dependency C++23 CLI and MCP server that maps a repo for coding agents";
    homepage = "https://github.com/redhat-et/ripwire";
    changelog = "https://github.com/redhat-et/ripwire/releases/tag/${sourceInfo.version}";
    license = lib.licenses.asl20;
    mainProgram = "ripwire";
    platforms = lib.platforms.unix;
  };
}
