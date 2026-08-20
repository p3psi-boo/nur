{
  lib,
  stdenv,
  zig_0_16,
  generated,
}:

let
  sourceInfo = generated.komari-agent-zig;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "komari-agent-zig";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  nativeBuildInputs = [ zig_0_16.hook ];

  zigBuildFlags = [ "-Dversion=${finalAttrs.version}" ];

  # The project's build.zig uses b.installArtifact, so the default
  # `zig build install --prefix $out` already places the binary in $out/bin.
  dontUseZigCheck = true;

  meta = {
    homepage = "https://github.com/luodaoyi/komari-zig-agent";
    description = "Zig implementation of komari-agent, compatible with the Komari monitoring protocol";
    license = lib.licenses.mit;
    mainProgram = "komari-agent";
    platforms = lib.platforms.unix;
  };
})
