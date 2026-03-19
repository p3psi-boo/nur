{
  generated,
  lib,
  fish,
  python3Packages,
}:

let
  sourceInfo = generated."fish-ai";
  py = python3Packages;
in
py.buildPythonApplication {
  pname = "fish-ai";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  pyproject = true;

  build-system = [ py.setuptools ];

  dependencies = [
    py.openai
    py.simple-term-menu
    py.iterfzf
    py.mistralai
    py.binaryornot
    py.anthropic
    py.cohere
    py.keyring
    py.groq
    py.google-genai
    py.httpx
    py.socksio
  ];

  pythonRelaxDeps = true;

  postPatch = ''
    substituteInPlace src/fish_ai/engine.py \
      --replace-fail 'return expandvars('"'"'$XDG_DATA_HOME/fish-ai'"'"')' 'return "'$out'"' \
      --replace-fail 'return expanduser('"'"'~/.local/share/fish-ai'"'"')' 'return "'$out'"'

    substituteInPlace src/fish_ai/autocomplete.py \
      --replace-fail "executable='/usr/bin/fish'" "executable='${lib.getExe fish}'"
  '';

  postInstall = ''
    install -Dm644 conf.d/fish_ai.fish $out/share/fish/vendor_conf.d/fish_ai.fish
    install -Dm644 functions/*.fish -t $out/share/fish/vendor_functions.d

    substituteInPlace $out/share/fish/vendor_conf.d/fish_ai.fish \
      --replace-fail 'set -g _fish_ai_install_dir (test -z "$XDG_DATA_HOME"; and echo "$HOME/.local/share/fish-ai"; or echo "$XDG_DATA_HOME/fish-ai")' "set -g _fish_ai_install_dir \"$out\""
  '';

  doCheck = false;

  pythonImportsCheck = [ "fish_ai" ];

  meta = {
    description = "AI assistant plugin for Fish shell";
    homepage = "https://github.com/Realiserad/fish-ai";
    changelog = "https://github.com/Realiserad/fish-ai/releases/tag/${sourceInfo.version}";
    license = lib.licenses.mit;
    mainProgram = "codify";
  };
}
