# Infisical server

Native **x86_64-linux** package of the official `infisical-core` Debian release,
not the `infisical` CLI. This is binary repackaging, not a source build.

The package retains the backend, Web UI, production dependencies and the exact
Node.js runtime shipped by upstream. Nix patches the ELF interpreter and native
addon library paths. Omnibus, Ruby, Chef, runit and Debian installation scripts
are not installed or executed. PostgreSQL and Redis are separate services.

The release includes MIT community code and enterprise-licensed code; the
derivation is marked `unfree` and excluded from Hydra builds.
Upstream notices are preserved under `share/licenses/infisical-server`.
Packaging does not change feature licensing.

## Build and test

From the NUR repository:

```sh
nix build .#infisical-server
nix build .#infisical-server.tests.smoke -L
```

The smoke test uses disposable local PostgreSQL 16 and Redis instances, fresh
random keys, a new database, and no external network. It checks automatic
migrations, `/api/status`, the Web UI, runtime UI configuration, graceful
SIGTERM shutdown and restart against the existing database.

## Runtime

Run `bin/infisical-server` directly in the foreground. Configuration uses
[upstream environment variables](https://infisical.com/docs/self-hosting/configuration/envars).
Required deployment configuration:

- `ENCRYPTION_KEY`: stable 16-byte random key encoded as 32 hexadecimal characters.
- `AUTH_SECRET`: stable 32-byte random value encoded as base64.
- `DB_CONNECTION_URI`: PostgreSQL connection URI.
- `REDIS_URL`: Redis connection URI.
- `SITE_URL`: the externally reachable HTTPS URL.

The wrapper defaults to `NODE_ENV=production`, `STANDALONE_MODE=true`,
`HOST=127.0.0.1`, `PORT=8080`, and the packaged platform version. These defaults
can be overridden with environment variables. The Web UI is served by the same
process. No `.env` file is written to the Nix store.

Example systemd integration in NixOS (database, Redis, TLS proxy and secret
provisioning deliberately belong to the host configuration):

```nix
systemd.services.infisical = {
  wantedBy = [ "multi-user.target" ];
  after = [ "network.target" ];
  environment = {
    SITE_URL = "https://secrets.example.org";
    TELEMETRY_ENABLED = "false";
    DISABLE_UPDATE_CHECK = "true";
  };
  serviceConfig = {
    Type = "simple";
    ExecStart = "${pkgs.infisical-server}/bin/infisical-server";
    EnvironmentFile = "/run/secrets/infisical-env";
    DynamicUser = true;
    StateDirectory = "infisical";
    WorkingDirectory = "/var/lib/infisical";
    PrivateTmp = true;
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    Restart = "on-failure";
    RestartSec = 5;
    TimeoutStopSec = 60;
  };
};
```

The wrapper changes into its immutable application directory for upstream
relative asset resolution. Temporary files use `TMPDIR`/the systemd private
`/tmp`; persistent application data lives in PostgreSQL and Redis. Keep
`ENCRYPTION_KEY` stable and back it up with the database.

This package does not provision accounts, configure SMTP, initialize production
secrets, expose ports, or enable any host service. Optional third-party/HSM
integrations are not covered by the smoke test.

## Updates

From the parent `nixcfg` repository, where `keyfile.toml` lives:

```sh
nix develop ./nur -c nvfetcher \
  -o nur/_sources -c nur/nvfetcher.toml \
  --keyfile ./keyfile.toml --filter '^infisical-server$'
```

The recipe tracks stable server tags and the official `-1_amd64.deb` artifact.
Re-run both build and integration test after updates: upstream can change Node
ABI, native dependencies, artifact layout or migration requirements.
