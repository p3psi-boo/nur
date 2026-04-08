{
  generated,
  lib,
  fish,
  stdenv,
  runCommand,
  rsync,
  makeWrapper,
  uv-builder,
}:

let
  sourceInfo = generated."fish-ai";
  version = lib.removePrefix "v" sourceInfo.version;

  workspaceRoot = runCommand "fish-ai-workspace-${version}" { } ''
    cp -r ${sourceInfo.src} $out
    chmod -R u+w $out
    cp ${./uv.lock} $out/uv.lock
  '';

  pythonEnv = uv-builder.buildUvPackage {
    pname = "fish-ai";
    inherit version workspaceRoot;
    bins = [
      "autocomplete"
      "codify"
      "explain"
      "fix"
      "lookup_setting"
      "put_api_key"
      "put_setting"
      "refine"
      "switch_context"
    ];

    pyprojectOverrides =
      _pyFinal: pyPrev: {
        "fish-ai" = pyPrev."fish-ai".overrideAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace src/fish_ai/engine.py \
              --replace-fail 'return expandvars('"'"'$XDG_DATA_HOME/fish-ai'"'"')' 'return environ.get('"'"'FISH_AI_INSTALL_DIR'"'"', expandvars('"'"'$XDG_DATA_HOME/fish-ai'"'"'))' \
              --replace-fail 'return expanduser('"'"'~/.local/share/fish-ai'"'"')' 'return environ.get('"'"'FISH_AI_INSTALL_DIR'"'"', expanduser('"'"'~/.local/share/fish-ai'"'"'))'

            substituteInPlace src/fish_ai/autocomplete.py \
              --replace-fail "executable='/usr/bin/fish'" "executable='${lib.getExe fish}'"
          '';
        });
      };
  };
in
stdenv.mkDerivation {
  pname = "fish-ai";
  inherit version;

  dontUnpack = true;
  dontBuild = true;

  nativeBuildInputs = [ rsync makeWrapper ];

  installPhase = ''
    mkdir -p $out

    # Copy uv2nix-built Python environment while preserving symlinks.
    ${rsync}/bin/rsync -a --chmod=u+w ${pythonEnv}/ $out/

    install -Dm644 ${sourceInfo.src}/conf.d/fish_ai.fish $out/share/fish/vendor_conf.d/fish_ai.fish
    install -Dm644 ${sourceInfo.src}/functions/*.fish -t $out/share/fish/vendor_functions.d

    substituteInPlace $out/share/fish/vendor_conf.d/fish_ai.fish \
      --replace-fail 'set -g _fish_ai_install_dir (test -z "$XDG_DATA_HOME"; and echo "$HOME/.local/share/fish-ai"; or echo "$XDG_DATA_HOME/fish-ai")' "set -g _fish_ai_install_dir \"$out\""

    for bin in $out/bin/*; do
      wrapProgram "$bin" --set FISH_AI_INSTALL_DIR "$out"
    done
  '';

  meta = {
    description = "AI assistant plugin for Fish shell";
    homepage = "https://github.com/Realiserad/fish-ai";
    changelog = "https://github.com/Realiserad/fish-ai/releases/tag/${sourceInfo.version}";
    license = lib.licenses.mit;
    mainProgram = "codify";
  };
}
