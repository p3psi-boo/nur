# Dagu

Packages the official release binary, including the embedded Web UI, for
Linux and Darwin on x86_64 and aarch64. Upstream v2.18.2 requires Go 1.27,
which is newer than the Go toolchain in the current nixpkgs lock.

```sh
nix build .#dagu
nix run .#dagu -- version
nix run .#dagu -- server --host 127.0.0.1 --port 8080
nix build .#dagu.tests.version
```

Release versions and archive hashes are managed by the four `dagu-*`
entries in `nvfetcher.toml`. From the parent nixcfg repository, update with:

```sh
nix develop ./nur -c nvfetcher -o nur/_sources -c nur/nvfetcher.toml \
  --keyfile ./keyfile.toml -f '^dagu-'
```

The x86_64-darwin archive is available, but the current unstable nixpkgs
input has dropped that platform. Use this package with a nixpkgs version
that still supports Intel Darwin (such as 26.05) for that platform.
