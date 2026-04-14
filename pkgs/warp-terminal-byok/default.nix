{ pkgs ? import <nixpkgs> { config.allowUnfree = true; }
, warp-terminal ? pkgs.warp-terminal
}:

let
  python = pkgs.python3.withPackages (ps: with ps; [
    aiohttp
    loguru
    yarl
    protobuf
  ]);
in

pkgs.stdenv.mkDerivation rec {
  pname = "warp-terminal-byok";
  version = "0.1.0";

  src = ./src;

  buildInputs = [ python ];

  # All protobuf Python files are pre-generated in warp_proto/
  # No build phase needed - skip to avoid protoc version mismatches

  installPhase = ''
    mkdir -p $out/{bin,lib/warp-terminal-byok,share/applications}

    # Copy Python files
    cp *.py $out/lib/warp-terminal-byok/
    cp -r warp_proto $out/lib/warp-terminal-byok/

    # Create main wrapper - WARP_BINARY injected at build time
    cat > $out/bin/warp-byok << EOF
    #!${pkgs.runtimeShell}
    export WARP_BINARY="${warp-terminal}/bin/warp-terminal"
    exec ${python}/bin/python $out/lib/warp-terminal-byok/launch_warp_linux.py "\$@"
    EOF
    chmod +x $out/bin/warp-byok

    # Create .desktop entry
    cat > $out/share/applications/warp-byok.desktop << EOF
    [Desktop Entry]
    Name=Warp (BYOK)
    Comment=Warp Terminal with Bring Your Own Key support
    Exec=$out/bin/warp-byok
    Type=Application
    Terminal=false
    Icon=warp-terminal
    Categories=System;TerminalEmulator;
    Keywords=terminal;warp;ai;byok;
    EOF
  '';

  meta = with pkgs.lib; {
    description = "Warp Terminal with BYOK (Bring Your Own Key) support";
    longDescription = ''
      Warp Terminal shim proxy that enables Bring Your Own Key (BYOK)
      functionality on Linux. Intercepts AI requests and forwards them
      to your own OpenAI, Anthropic, or Google API endpoints.
    '';
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "warp-byok";
  };
}
