{
  lib,
  stdenvNoCC,
  generated,
  makeWrapper,
}:

let
  sourceInfo = generated.rikugan;
  version = lib.removePrefix "v" sourceInfo.version;
in
stdenvNoCC.mkDerivation {
  pname = "rikugan";
  inherit version;

  src = sourceInfo.src;
  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    pkgRoot="$out/share/rikugan"
    mkdir -p "$pkgRoot"

    cp -r \
      assets \
      rikugan \
      __init__.py \
      plugin.json \
      ida-plugin.json \
      rikugan_binaryninja.py \
      rikugan_plugin.py \
      requirements.txt \
      install.sh \
      install_ida.sh \
      install_binaryninja.sh \
      README.md \
      "$pkgRoot/"

    patchShebangs "$pkgRoot"

    makeWrapper "$pkgRoot/install_ida.sh" "$out/bin/rikugan-install-ida"
    makeWrapper "$pkgRoot/install_binaryninja.sh" "$out/bin/rikugan-install-binja"

    cat > "$out/bin/rikugan-install" <<'EOF'
@SHELL@
set -euo pipefail

case "''${1:-}" in
  --ida)
    shift
    exec "@OUT@/bin/rikugan-install-ida" "$@"
    ;;
  --binja|--bn)
    shift
    exec "@OUT@/bin/rikugan-install-binja" "$@"
    ;;
  --both|"")
    if [ "''${1:-}" = "--both" ]; then
      shift
    fi
    "@OUT@/bin/rikugan-install-ida" "$@"
    "@OUT@/bin/rikugan-install-binja" "$@"
    ;;
  --help|-h)
    cat <<USAGE
Usage: rikugan-install [--ida | --binja | --both] [host-user-dir]

  --ida     Install Rikugan for IDA Pro only
  --binja   Install Rikugan for Binary Ninja only
  --both    Install for both hosts (default)

This wrapper runs Rikugan's upstream install scripts from the Nix store.
The scripts will install Python dependencies into the host application's
Python environment via pip, then symlink the plugin files from:
  @OUT@/share/rikugan
USAGE
    ;;
  *)
    echo "Unknown option: $1" >&2
    echo "Try: rikugan-install --help" >&2
    exit 1
    ;;
esac
EOF
    substituteInPlace "$out/bin/rikugan-install" \
      --replace-fail '@SHELL@' '#!${stdenvNoCC.shell}' \
      --replace-fail '@OUT@' "$out"
    chmod +x "$out/bin/rikugan-install"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Agentic reverse-engineering companion for IDA Pro and Binary Ninja";
    homepage = "https://github.com/buzzer-re/Rikugan";
    license = licenses.mit;
    mainProgram = "rikugan-install";
    platforms = platforms.unix;
  };
}
