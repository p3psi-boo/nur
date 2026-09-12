{
  lib,
  caddy,
}:

caddy.withPlugins {
  plugins = [ "github.com/caddy-dns/tencentcloud@v0.4.3" ];
  hash = "sha256-9PJUAeRR6uoLsNGi60+0tk1Zuqj64i6HBpC0IScpaJM=";
}
