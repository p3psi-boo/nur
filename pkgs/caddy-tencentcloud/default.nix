{
  lib,
  caddy,
}:

caddy.withPlugins {
  plugins = [ "github.com/caddy-dns/tencentcloud@v0.4.3" ];
  hash = "sha256-neMT9QehGEDSt3TrteR9H939FsjMXF78Dc8SJQxvXpg=";
}
