{
  lib,
  caddy,
}:

caddy.withPlugins {
  plugins = [ "github.com/caddy-dns/tencentcloud@v0.4.3" ];
  hash = "sha256-abj6mqDMXwdTBZKn0hR1RNBwDwjn9P5zoFf2xEaZlsQ=";
}
