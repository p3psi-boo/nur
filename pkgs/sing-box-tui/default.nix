{
  lib,
  buildGoModule,
  buf,
  protobuf,
  protoc-gen-go,
  protoc-gen-go-grpc,
  generated,
}:

let
  sourceInfo = generated.sing-box-tui;
in
buildGoModule (finalAttrs: {
  pname = "sing-box-tui";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  nativeBuildInputs = [
    buf
    protobuf
    protoc-gen-go
    protoc-gen-go-grpc
  ];

  vendorHash = "sha256-4ls753MZucJQX9o0mzx89zs6GX3CWjSk+7Rzobn6GZ4=";

  # The upstream source keeps protobuf definitions and generates Go bindings
  # during the build rather than committing the generated code.
  preBuild = ''
    export HOME="$TMPDIR"
    export XDG_CACHE_HOME="$TMPDIR/.cache"
    buf generate
  '';

  subPackages = [ "cmd/sing-box-tui" ];

  ldflags = [
    "-s"
    "-w"
  ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    go test ./...
    runHook postCheck
  '';

  meta = {
    description = "Terminal UI for sing-box management APIs";
    homepage = "https://github.com/p3psi-boo/sing-box-tui";
    changelog = "https://github.com/p3psi-boo/sing-box-tui/commits/${sourceInfo.version}";
    license = lib.licenses.wtfpl;
    mainProgram = "sing-box-tui";
    platforms = lib.platforms.unix;
  };
})
