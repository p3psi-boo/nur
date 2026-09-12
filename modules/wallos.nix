{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.wallos;
  php = cfg.package.php;
  pool = config.services.phpfpm.pools.wallos;
  timezoneOption = lib.optionalString (
    config.time.timeZone != null
  ) "-d date.timezone=${config.time.timeZone}";
  # Copy code, rather than linking individual PHP files: __DIR__ must resolve
  # inside this tree so relative database/upload paths reach the state links.
  webroot = pkgs.runCommand "wallos-webroot-${cfg.package.version}" { } ''
    cp -r ${cfg.package} "$out"
    chmod -R u+w "$out"
    rm -rf "$out/db" "$out/.tmp" "$out/images/uploads/logos"
    ln -s ${lib.escapeShellArg "${cfg.dataDir}/db"} "$out/db"
    ln -s ${lib.escapeShellArg "${cfg.dataDir}/tmp"} "$out/.tmp"
    ln -s ${lib.escapeShellArg "${cfg.dataDir}/logos"} "$out/images/uploads/logos"
  '';
  # Schedules are copied from the upstream cronjobs file.
  jobs = {
    updatenextpayment.calendar = "*-*-* 01:00:00";
    updateexchange.calendar = "*-*-* 02:00:00";
    sendcancellationnotifications.calendar = "*-*-* 08:00:00";
    sendnotifications.calendar = "*-*-* 09:00:00";
    sendverificationemails.calendar = "*-*-* *:0/2:00";
    sendresetpasswordemails.calendar = "*-*-* *:0/2:00";
    checkforupdates.calendar = "*-*-* 0/6:00:00";
    storetotalyearlycost.calendar = "Mon *-*-* 01:30:00";
    cleanupresettokens.calendar = "*-*-* 03:00:00";
    recommendations-weekly = {
      calendar = "Mon *-*-* 03:30:00";
      command = "generaterecommendations.php weekly";
    };
    recommendations-monthly = {
      calendar = "*-*-01 04:00:00";
      command = "generaterecommendations.php monthly";
    };
  };
in
{
  options.services.wallos = {
    enable = lib.mkEnableOption "Wallos subscription tracker";
    package = lib.mkOption {
      type = lib.types.package;
      default = (import ../repo.nix { inherit pkgs; }).wallos;
      defaultText = lib.literalExpression "nur.packages.\${system}.wallos";
      description = "Wallos package, including its PHP runtime in passthru.php.";
    };
    hostName = lib.mkOption {
      type = lib.types.str;
      description = "Name of the nginx virtual host. Configure its listeners and TLS through services.nginx.virtualHosts.";
      example = "wallos.example.org";
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/wallos";
      description = "Absolute directory holding the database, uploaded logos and temporary restore files.";
    };
    poolSettings = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.oneOf [
          lib.types.str
          lib.types.int
          lib.types.bool
        ]
      );
      default = {
        pm = "ondemand";
        "pm.max_children" = 15;
        "pm.max_requests" = 500;
      };
      description = "PHP-FPM process settings. Process and request limits match the upstream Dockerfile.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.wallos.dataDir must be an absolute path.";
      }
    ];

    users.groups.wallos = { };
    users.users.wallos = {
      isSystemUser = true;
      group = "wallos";
    };
    systemd.tmpfiles.settings.wallos = {
      "${cfg.dataDir}".d = {
        user = "wallos";
        group = "wallos";
        mode = "0755";
      };
      "${cfg.dataDir}/db".d = {
        user = "wallos";
        group = "wallos";
        mode = "0700";
      };
      "${cfg.dataDir}/tmp".d = {
        user = "wallos";
        group = "wallos";
        mode = "0700";
      };
      "${cfg.dataDir}/logos".d = {
        user = "wallos";
        group = "wallos";
        mode = "0755";
      };
      "${cfg.dataDir}/logos/avatars".d = {
        user = "wallos";
        group = "wallos";
        mode = "0755";
      };
    };

    services.phpfpm.pools.wallos = {
      user = "wallos";
      group = "wallos";
      phpPackage = php;
      settings = cfg.poolSettings // {
        "listen.owner" = config.services.nginx.user;
        "listen.group" = config.services.nginx.group;
        "listen.mode" = "0600";
      };
      # Match the upload limits in the upstream Dockerfile/nginx config.
      phpOptions = ''
        upload_max_filesize = 256M
        post_max_size = 256M
      ''
      + lib.optionalString (config.time.timeZone != null) ''
        date.timezone = ${config.time.timeZone}
      '';
    };
    systemd.services = {
      phpfpm-wallos = {
        requires = [ "wallos-init.service" ];
        after = [ "wallos-init.service" ];
        restartTriggers = [ webroot ];
      };
      wallos-init = {
        description = "Initialize and migrate the Wallos database";
        requiredBy = [ "phpfpm-wallos.service" ];
        before = [ "phpfpm-wallos.service" ];
        after = [ "systemd-tmpfiles-setup.service" ];
        serviceConfig = {
          Type = "oneshot";
          User = "wallos";
          Group = "wallos";
          WorkingDirectory = webroot;
          RemainAfterExit = true;
          UMask = "0022";
        };
        script = ''
          ${php}/bin/php endpoints/cronjobs/createdatabase.php
          ${php}/bin/php endpoints/db/migrate.php
        '';
        restartTriggers = [ webroot ];
      };
    }
    // lib.mapAttrs' (
      name: job:
      lib.nameValuePair "wallos-${name}" {
        description = "Wallos ${name}";
        requires = [ "wallos-init.service" ];
        after = [ "wallos-init.service" ];
        serviceConfig = {
          Type = "oneshot";
          User = "wallos";
          Group = "wallos";
          WorkingDirectory = webroot;
          ExecStart = "${php}/bin/php ${timezoneOption} endpoints/cronjobs/${job.command or "${name}.php"}";
        };
      }
    ) jobs;
    systemd.timers = lib.mapAttrs' (
      name: job:
      lib.nameValuePair "wallos-${name}" {
        wantedBy = [ "timers.target" ];
        timerConfig.OnCalendar = job.calendar;
      }
    ) jobs;

    services.nginx.enable = true;
    services.nginx.virtualHosts.${cfg.hostName} = {
      root = webroot;
      extraConfig = "client_max_body_size 256M;";
      locations = {
        "/".tryFiles = "$uri $uri/ /index.php?$args";
        # Prefix blocks take precedence over PHP execution, including uploads.
        "^~ /db/".return = "403";
        "^~ /.tmp/".return = "403";
        "^~ /includes/".return = "403";
        "^~ /images/uploads/logos/" = {
          extraConfig = ''
            add_header X-Content-Type-Options nosniff;
            location ~* \.php { return 403; }
          '';
        };
        "~ \\.php$" = {
          tryFiles = "$uri =404";
          extraConfig = ''
            include ${config.services.nginx.package}/conf/fastcgi_params;
            fastcgi_pass unix:${pool.socket};
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
          '';
        };
      };
    };
  };
}
