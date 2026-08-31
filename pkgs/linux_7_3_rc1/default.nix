{
  lib,
  buildLinux,
  generated,
  ...
}@args:

let
  source = generated.linux_7_3_rc1;
in
buildLinux (
  (removeAttrs args [ "generated" ])
  // {
    inherit (source) src version;

    modDirVersion = lib.versions.pad 3 source.version;

    extraMeta.branch = "7.3";
  }
  // (args.argsOverride or { })
)
