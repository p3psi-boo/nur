{ pkgs ? import <nixpkgs> {}, lib ? pkgs.lib }:

pkgs.stdenv.mkDerivation (finalAttrs: {
  pname = "ssh-sync";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    cp ssh-sync $out/bin/ssh-sync
    chmod +x $out/bin/ssh-sync
    wrapProgram $out/bin/ssh-sync --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.gh pkgs.jq ]}
  '';

  meta = with lib; {
    description = "A script to synchronize local ssh config and lazyssh metadata with a GitHub Gist.";
    license = licenses.mit;
    platforms = platforms.all;
    mainProgram = "ssh-sync";
  };
})