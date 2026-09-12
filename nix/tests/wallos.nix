{ pkgs }:

pkgs.testers.runNixOSTest {
  name = "wallos";
  nodes.machine = { ... }: {
    imports = [ ../../modules/wallos.nix ];
    suites.wallos = {
      enable = true;
      hostName = "wallos.test";
      # Exercise the configurable state path, not only its default.
      dataDir = "/var/lib/wallos-test";
    };
    services.nginx.virtualHosts."wallos.test".listen = [
      {
        addr = "127.0.0.1";
        port = 80;
      }
    ];
    environment.systemPackages = [
      pkgs.curl
      pkgs.sqlite
    ];
  };
  testScript = ''
    machine.start()
    machine.wait_for_unit("nginx.service")
    machine.wait_for_unit("phpfpm-wallos.service")
    machine.succeed("curl -fsS -H 'Host: wallos.test' http://127.0.0.1/health.php | grep -x OK")
    machine.succeed("curl -fsS -H 'Host: wallos.test' http://127.0.0.1/registration.php | grep -i '<form'")
    machine.succeed("test -s /var/lib/wallos-test/db/wallos.db")
    machine.succeed("sqlite3 /var/lib/wallos-test/db/wallos.db 'SELECT COUNT(*) > 0 FROM migrations' | grep -x 1")
    machine.succeed("echo persistent > /var/lib/wallos-test/logos/persistent.txt")
    machine.succeed("echo '<?php echo 12345; ?>' > /var/lib/wallos-test/logos/probe.php")
    for path in ["db/wallos.db", ".tmp/probe.php", "includes/connect.php", "images/uploads/logos/probe.php"]:
        status = machine.succeed(f"curl -s -o /dev/null -w '%{{http_code}}' -H 'Host: wallos.test' http://127.0.0.1/{path}").strip()
        assert status == "403", (path, status)
    machine.succeed("curl -fsS -H 'Host: wallos.test' http://127.0.0.1/images/uploads/logos/persistent.txt | grep -x persistent")
    machine.succeed("systemctl start wallos-updatenextpayment.service")
    machine.succeed("systemctl is-active wallos-sendnotifications.timer")
    machine.succeed("systemctl restart wallos-init.service phpfpm-wallos.service")
    machine.succeed("grep -x persistent /var/lib/wallos-test/logos/persistent.txt")
    machine.succeed("curl -fsS -H 'Host: wallos.test' http://127.0.0.1/registration.php | grep -i '<form'")
  '';
}
