{
  lib,
  buildDotnetModule,
  dotnetCorePackages,
  fetchFromGitHub,
  generated ? null,
}:

buildDotnetModule (finalAttrs: let
  sourceInfo =
    if generated != null && generated ? il2cppdumper then
      generated.il2cppdumper
    else
      rec {
        version = "v6.7.46";
        src = fetchFromGitHub {
          owner = "Perfare";
          repo = "Il2CppDumper";
          rev = version;
          hash = lib.fakeHash;
        };
      };
in {
  pname = "il2cppdumper";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  postPatch = ''
    substituteInPlace Il2CppDumper/config.json \
      --replace-fail '"RequireAnyKey": true' '"RequireAnyKey": false'
  '';

  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  dotnet-runtime = dotnetCorePackages.runtime_8_0;
  dotnetFlags = [ "-p:TargetFramework=net8.0" ];

  projectFile = "Il2CppDumper/Il2CppDumper.csproj";
  nugetDeps = ./deps.json;

  postInstall = ''
    ln -s $out/bin/Il2CppDumper $out/bin/il2cppdumper
  '';

  meta = {
    description = "Unity il2cpp reverse engineering tool";
    homepage = "https://github.com/Perfare/Il2CppDumper";
    changelog = "https://github.com/Perfare/Il2CppDumper/releases/tag/${sourceInfo.version}";
    license = lib.licenses.mit;
    mainProgram = "il2cppdumper";
    platforms = lib.platforms.unix;
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryBytecode
    ];
  };
})
