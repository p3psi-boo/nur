{
  pkgs,
  lib,
  extraFiles ? "",
  ...
}:
let
  pythonForIDA = pkgs.python313.withPackages (ps: with ps; [ rpyc ]);
  
  idaKeygen = pkgs.writeText "ida-keygen.py" ''
    import hashlib
    import json
    from pathlib import Path
    import sys

    if len(sys.argv) != 2:
        print("Usage: ida-keygen.py <ida_install_path>")
        sys.exit(1)

    LOCATION = Path(sys.argv[1])
    VERSION = "9.4.0"  # Match package version
    
    NAME = "meow@colonthree"
    EMAIL = "nixos@localhost"
    ID_PREFIX = "48-3FBD-7F04"

    license = {
        "header": {"version": 1},
        "payload": {
            "name": NAME,
            "email": EMAIL,
            "licenses": [
                {
                    "description": "license",
                    "edition_id": "ida-pro",
                    "id": f"{ID_PREFIX}-00",
                    "license_type": "named",
                    "product": "IDA",
                    "seats": 1,
                    "start_date": "2024-08-10 00:00:00",
                    "end_date": "2033-12-31 23:59:59",
                    "issued_on": "2024-08-10 00:00:00",
                    "owner": NAME,
                    "product_id": "IDAPRO",
                    "add_ons": [],
                    "features": [],
                }
            ],
        },
    }

    def add_every_addon(license):
        addons = [
            "HEXX86", "HEXX64", "HEXARM", "HEXARM64",
            "HEXMIPS", "HEXMIPS64", "HEXPPC", "HEXPPC64",
            "HEXRV64", "HEXARC", "HEXARC64",
        ]
        for i, addon in enumerate(addons, start=1):
            license["payload"]["licenses"][0]["add_ons"].append({
                "id": f"{ID_PREFIX}-{i:02}",
                "code": addon,
                "owner": license["payload"]["licenses"][0]["id"],
                "start_date": "2024-08-10 00:00:00",
                "end_date": "2033-12-31 23:59:59",
            })

    add_every_addon(license)

    def json_stringify_alphabetical(obj):
        return json.dumps(obj, sort_keys=True, separators=(",", ":"))

    def buf_to_bigint(buf):
        return int.from_bytes(buf, byteorder="little")

    def bigint_to_buf(i):
        return i.to_bytes((i.bit_length() + 7) // 8, byteorder="little")

    pub_modulus_patched = buf_to_bigint(bytes.fromhex(
        "edfd42cbf978546e8911225884436c57140525650bcf6ebfe80edbc5fb1de68f4c66c29cb22eb668788afcb0abbb718044584b810f8970cddf227385f75d5dddd91d4f18937a08aa83b28c49d12dc92e7505bb38809e91bd0fbd2f2e6ab1d2e33c0c55d5bddd478ee8bf845fcef3c82b9d2929ecb71f4d1b3db96e3a8e7aaf93"
    ))

    private_key = buf_to_bigint(bytes.fromhex(
        "77c86abbb7f3bb134436797b68ff47beb1a5457816608dbfb72641814dd464dd640d711d5732d3017a1c4e63d835822f00a4eab619a2c4791cf33f9f57f9c2ae4d9eed9981e79ac9b8f8a411f68f25b9f0c05d04d11e22a3a0d8d4672b56a61f1532282ff4e4e74759e832b70e98b9d102d07e9fb9ba8d15810b144970029874"
    ))

    def encrypt(message):
        encrypted = pow(buf_to_bigint(message[::-1]), private_key, pub_modulus_patched)
        encrypted = bigint_to_buf(encrypted)
        return encrypted

    def sign_hexlic(payload):
        data = {"payload": payload}
        data_str = json_stringify_alphabetical(data)
        buffer = bytearray(128)
        for i in range(33):
            buffer[i] = 0x42
        sha256 = hashlib.sha256()
        sha256.update(data_str.encode())
        digest = sha256.digest()
        for i in range(32):
            buffer[33 + i] = digest[i]
        encrypted = encrypt(buffer)
        return encrypted.hex().upper()

    def patch_libida(filename_path):
        filename = filename_path.name
        if not filename_path.exists():
            print(f"Didn't find {filename}, skipping")
            return
        data = filename_path.read_bytes()
        if data.find(bytes.fromhex("EDFD42CBF978")) != -1:
            print(f"{filename} already patched")
            return
        if data.find(bytes.fromhex("EDFD425CF978")) == -1:
            print(f"{filename} doesn't contain original modulus")
            return
        data = data.replace(bytes.fromhex("EDFD425CF978"), bytes.fromhex("EDFD42CBF978"))
        filename_path.write_bytes(data)
        print(f"Patched {filename}")

    license["signature"] = sign_hexlic(license["payload"])
    serialized = json_stringify_alphabetical(license)
    
    license_path = LOCATION / "idapro.hexlic"
    license_path.write_text(serialized, encoding="utf-8")
    print(f"Saved license to {license_path}")

    for lib in ["libida.so", "libida32.so", "libida64.so"]:
        patch_libida(LOCATION / lib)

    print("Keygen complete!")
  '';
in
pkgs.stdenv.mkDerivation (finalAttrs: {
  pname = "ida-pro";
  version = "9.4";

  src = pkgs.fetchurl {
    name = "ida-pro_94_x64linux.run";
    url = "https://archive.org/download/ida-pro-94/ida-pro_94_x64linux.run";
    sha256 = "sha256-6rtkw8hJ04WHWVWDWenOvPF+KpH8xgUVUz37iERii1Q=";
  };

  desktopItem = pkgs.makeDesktopItem {
    name = "ida-pro";
    exec = "ida";
    icon = ./appico.png;
    comment = finalAttrs.meta.description;
    desktopName = "IDA Pro";
    genericName = "Interactive Disassembler";
    categories = [ "Development" ];
    startupWMClass = "IDA";
  };
  desktopItems = [ finalAttrs.desktopItem ];

  nativeBuildInputs = with pkgs; [
    makeWrapper
    copyDesktopItems
    autoPatchelfHook
    qt6.wrapQtAppsHook
    python3
  ];

  autoPatchelfIgnoreMissingDeps = [
    "libQt6WaylandCompositor.so.6"
    "libQt6EglFSDeviceIntegration.so.6"
    "libQt6WlShellIntegration.so.6"
    "libQt6Network.so.6"
    "libQt6Svg.so.6"
    "libQt6Core.so.6"
    "libQt6Gui.so.6"
    "libQt6Widgets.so.6"
    "libpython3.*\\.so"
  ];

  dontUnpack = true;

  runtimeDependencies = with pkgs; [
    cairo
    dbus
    fontconfig
    freetype
    glib
    gtk3
    libdrm
    libGL
    libkrb5
    libsecret
    qt6.qtbase
    qt6.qtwayland
    libunwind
    libxkbcommon
    libsecret
    openssl.out
    stdenv.cc.cc
    libice
    libsm
    libx11
    libxau
    libxcb
    libxext
    libxi
    libxrender
    libxcb-image
    libxcb-keysyms
    libxcb-render-util
    libxcb-wm
    xcb-util-cursor
    libxcrypt-legacy
    zlib
    curl.out
    pythonForIDA
  ];
  buildInputs = finalAttrs.runtimeDependencies;

  dontWrapQtApps = true;

  installPhase = ''
    runHook preInstall

    function print_debug_info() {
      if [ -f installbuilder_installer.log ]; then
        cat installbuilder_installer.log
      else
        echo "No debug information available."
      fi
    }

    trap print_debug_info EXIT

    mkdir -p $out/bin $out/lib $out/opt/.local/share/applications

    IDADIR="$out/opt"
    HOME="$out/opt"

    $(cat $NIX_CC/nix-support/dynamic-linker) $src \
      --mode unattended --debuglevel 4 --prefix $IDADIR

    for lib in $IDADIR/*.so $IDADIR/*.so.6; do
      ln -s $lib $out/lib/$(basename $lib) 2>/dev/null || true
    done

    for libso in $out/lib/libida.so $out/lib/libida64.so $out/lib/libida32.so; do
      if [ -f "$libso" ]; then
        patchelf --add-needed libpython3.13.so "$libso" 2>/dev/null || true
        patchelf --add-needed libcrypto.so "$libso" 2>/dev/null || true
        patchelf --add-needed libsecret-1.so.0 "$libso" 2>/dev/null || true
      fi
    done

    # IDAPython 运行环境链接
    mkdir -p $IDADIR/opt/python/lib-dynload
    ln -sf ${pythonForIDA}/lib/libpython*.so $IDADIR/opt/python/ 2>/dev/null || true
    ln -sf ${pythonForIDA}/lib/python*/lib-dynload/* $IDADIR/opt/python/lib-dynload/ 2>/dev/null || true

    addAutoPatchelfSearchPath $IDADIR

    echo "Running auto-crack keygen..."
    python3 ${idaKeygen} $IDADIR

    for bb in ida ida64 assistant; do
      if [ -f "$IDADIR/$bb" ]; then
        wrapProgram $IDADIR/$bb \
          --prefix IDADIR : $IDADIR \
          --set QT_QPA_PLATFORM xcb \
          --set QT_QPA_PLATFORM_PLUGIN_PATH $IDADIR/plugins/platforms \
          --set QT_PLUGIN_PATH $IDADIR/plugins \
          --unset QT_QPA_PLATFORMTHEME \
          --prefix PYTHONPATH : $IDADIR/opt/python:$out/bin/idalib/python \
          --prefix PATH : ${pythonForIDA}/bin:$IDADIR \
          --prefix LD_LIBRARY_PATH : $out/lib:$IDADIR:${pythonForIDA}/lib \
          --chdir $IDADIR
        ln -sf $IDADIR/$bb $out/bin/$bb
      fi
    done

    if [ -n "${extraFiles}" ]; then
      cp -r "${extraFiles}"/* $out/opt/
    fi

    runHook postInstall
  '';

  meta = with lib; {
    description = "The world's smartest and most feature-full disassembler";
    homepage = "https://hex-rays.com/ida-pro/";
    license = licenses.unfree;
    mainProgram = "ida";
    maintainers = with maintainers; [ msanft ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
})
