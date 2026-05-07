{ lib
, buildDotnetModule
, dotnetCorePackages
, ffmpeg
, generated
, makeWrapper
}:

let
  sourceInfo = generated.bbdown;
  pname = "BBDown";
  dotnet-sdk = dotnetCorePackages.sdk_9_0;
  dotnet-runtime = dotnet-sdk;
in
buildDotnetModule {
  inherit pname dotnet-sdk dotnet-runtime;
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  nugetDeps = ./deps.nix;

  projectFile = "BBDown/BBDown.csproj";

  selfContainedBuild = false;
  useDotnetFromEnv = true;

  dotnetBuildFlags = [ "-p:PublishAot=false" ];
  dotnetInstallFlags = [ "-p:PublishAot=false" ];

  doCheck = false;

  postFixup = ''
    wrapProgram $out/bin/${pname} \
      --prefix PATH : "${lib.makeBinPath [ ffmpeg ]}"
  '';

  meta = with lib; {
    description = "Bilibili Downloader";
    homepage = "https://github.com/nilaoda/BBDown";
    license = licenses.mit;
    mainProgram = pname;
    platforms = platforms.linux;
  };
}
