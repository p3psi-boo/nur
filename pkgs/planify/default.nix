{ lib
, stdenv
, generated
, meson
, ninja
, pkg-config
, vala
, gettext
, itstool
, wrapGAppsHook4
, desktop-file-utils
, glib
, gtk4
, libadwaita
, libgee
, libsoup_3
, sqlite
, json-glib
, libical
, gxml
, libsecret
, gtksourceview5
, webkitgtk_6_0 ? null
, libportal ? null
, libspelling ? null
, ...
}@args:

let
  sourceInfo = generated.planify;
  libportalGtk4 = args."libportal-gtk4" or null;
  withWebkit = webkitgtk_6_0 != null;
  withPortal = libportal != null && libportalGtk4 != null;
  withSpelling = libspelling != null;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "planify";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    vala
    gettext
    itstool
    wrapGAppsHook4
    desktop-file-utils
  ];

  buildInputs =
    [
      glib
      gtk4
      libadwaita
      libgee
      libsoup_3
      sqlite
      json-glib
      libical
      gxml
      libsecret
      gtksourceview5
    ]
    ++ lib.optionals withWebkit [ webkitgtk_6_0 ]
    ++ lib.optionals withPortal [
      libportal
      libportalGtk4
    ]
    ++ lib.optionals withSpelling [ libspelling ];

  mesonFlags = [
    "-Dprofile=default"
    "-Dtracing=false"
    "-Devolution=false"
    "-Dwebkit=${lib.boolToString withWebkit}"
    "-Dportal=${lib.boolToString withPortal}"
    "-Dspelling=${if withSpelling then "enabled" else "disabled"}"
  ];

  doCheck = false;

  meta = with lib; {
    description = "Task manager focused on productivity";
    homepage = "https://github.com/alainm23/planify";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    mainProgram = "io.github.alainm23.planify";
  };
})
