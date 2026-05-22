{
  lib,
  stdenv,
  autoPatchelfHook,
  makeWrapper,
  fetchurl,
  gnutar,
  gzip,
  ffmpeg,
  nodejs_22,
  chromium,
}:

let
  # Map platform to fpk download info
  platforms = {
    x86_64-linux = {
      arch = "x86";
      hash = "sha256-NdEnu9p6F4ioxhejC9QgnxVnt1b/Gq7IcwqZSn3L7Rc="; # 1.1.1.0 x86
    };
    aarch64-linux = {
      arch = "arm";
      hash = "sha256-DBoXIytkA6bPcALo3IFoiE/iliwPKbFdP9iLgiP3Nac="; # 1.1.1.0 arm
    };
  };

  platform = platforms.${stdenv.hostPlatform.system} or (throw "Unsupported platform for wxbackup: ${stdenv.hostPlatform.system}");

  version = "1.1.1.0";
in
stdenv.mkDerivation {
  pname = "wxbackup";
  inherit version;

  src = fetchurl {
    url = "https://github.com/weibeifen/wxbackup/releases/download/${version}/WxBackup_${version}_${platform.arch}.fpk";
    inherit (platform) hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    gnutar
    gzip
  ];

  buildInputs = [
    stdenv.cc.libc
  ];

  # fpk is gzip'd tar, containing app.tgz inside
  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack

    # Layer 1: fpk is gzip compressed tar
    mkdir -p fpk-contents
    gzip -dc $src | tar -xf - -C fpk-contents

    # Layer 2: extract inner app.tgz
    mkdir -p app-contents
    tar -xzf fpk-contents/app.tgz -C app-contents

    cd app-contents
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    # --- App lib directory (equivalent to /var/apps/WxBackup/var in fnOS) ---
    mkdir -p $out/lib/wxbackup
    mkdir -p $out/bin

    # --- Core binaries (closed source, extracted from fpk) ---
    install -Dm755 server/WxBackup $out/lib/wxbackup/WxBackup
    install -Dm755 ui/index.cgi    $out/lib/wxbackup/index.cgi

    # Note: server/updater not included — self-update mechanism is unnecessary
    # on NixOS where version management is handled by the package manager.

    # --- Web UI assets (from fpk, large) ---
    cp -r server/dist $out/lib/wxbackup/dist

    # --- svc.txt (empty marker file, binary references it) ---
    touch $out/lib/wxbackup/svc.txt

    # --- Replace bundled dependencies with nixpkgs equivalents ---

    # ffmpeg: symlink to nixpkgs ffmpeg (replaces bundled ~80MB static binary)
    ln -sf ${ffmpeg}/bin/ffmpeg $out/lib/wxbackup/ffmpeg

    # Chrome: create chrome-linux/ directory symlink to nixpkgs chromium
    # The WxBackup binary searches for Chrome in order:
    #   1. ./chrome-linux/chrome (from extracted chrome-linux.zip)
    #   2. /usr/bin/google-chrome / google-chrome-stable
    #   3. chromium-browser (in PATH)
    # We link nixpkgs chromium as both chrome-linux/chrome and provide
    # chromium-browser via PATH as a fallback.
    mkdir -p $out/lib/wxbackup/chrome-linux
    ln -sf ${chromium}/bin/chromium $out/lib/wxbackup/chrome-linux/chrome

    # --- Wrapper scripts ---

    # wxbackup: main daemon (needs Node.js in PATH + cwd set)
    makeWrapper $out/lib/wxbackup/WxBackup $out/bin/wxbackup \
      --set PATH ${lib.makeBinPath [ nodejs_22 ffmpeg chromium ]}:$PATH \
      --run "cd $out/lib/wxbackup"

    # wxbackup-cgi: web UI CGI server (statically linked Go binary)
    makeWrapper $out/lib/wxbackup/index.cgi $out/bin/wxbackup-cgi \
      --run "cd $out/lib/wxbackup"

    runHook postInstall
  '';

  # autoPatchelfHook fixes ELF interpreter + libc for WxBackup (dynamic Go binary)
  # index.cgi (static Go) and ffmpeg (nixpkgs symlink) need no fixing

  meta = with lib; {
    description = "WeChat backup tool for NAS (飞牛NAS 微备份)";
    longDescription = ''
      WxBackup (微备份) is a WeChat backup tool designed for NAS systems.
      Supports full/incremental backup, HarmonyOS/Android/iOS, and chat record browsing.

      Originally packaged for Feiniu NAS (fpk format), this Nix package:
      - Extracts the closed-source binaries from the fpk
      - Replaces bundled ffmpeg/Chrome/Node.js with nixpkgs equivalents
      - Uses autoPatchelfHook to fix the dynamic linker on NixOS

      Ports needed: 9014, 8011, 20360-20367, 20365
    '';
    homepage = "https://github.com/weibeifen/wxbackup";
    license = licenses.unfree; # closed source, commercial with free tier
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "wxbackup";
    maintainers = with maintainers; [ ];
  };
}
