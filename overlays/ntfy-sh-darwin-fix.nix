# Fix ntfy-sh build on Darwin: serve_unix.go excludes darwin from build tag
# Issue: https://github.com/binwiederhier/ntfy/issues/1631
# PR:   https://github.com/binwiederhier/ntfy/pull/1696
final: prev: {
  ntfy-sh = prev.ntfy-sh.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      # Add darwin to the Unix build tag so maybeRunAsService/sigHandlerConfigReload are available
      substituteInPlace cmd/serve_unix.go \
        --replace-fail 'linux || dragonfly || freebsd || netbsd || openbsd' \
                       'linux || dragonfly || freebsd || netbsd || openbsd || darwin'
    '';
  });
}
