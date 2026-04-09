{ lib
, rustPlatform
, generated
, pkg-config
, openssl
, stdenv
, darwin
}:

rustPlatform.buildRustPackage {
  pname = "oli";
  version = generated.oli.version;

  src = generated.oli.src;

  cargoHash = "sha256-HolrBSo/JaGhL4gYm8hzfsBFnOvv2xdmvvQXb+NfetI=";

  # Integration tests for `edit` command spawn an editor from temp path and fail in sandbox.
  doCheck = false;

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
  ] ++ lib.optionals stdenv.hostPlatform.isDarwin [
    darwin.apple_sdk.frameworks.Security
    darwin.apple_sdk.frameworks.SystemConfiguration
  ];

  meta = with lib; {
    description = "OpenDAL Command Line Interface";
    homepage = "https://opendal.apache.org";
    license = licenses.asl20;
    maintainers = [ ];
    mainProgram = "oli";
  };
}
