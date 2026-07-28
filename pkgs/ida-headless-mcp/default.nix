{
  lib,
  buildGoModule,
  generated,
  makeWrapper,
  python3,
  ida-pro,
}:

let
  sourceInfo = generated."ida-headless-mcp";
  pythonEnv = python3.withPackages (ps: with ps; [
    grpcio
    protobuf
  ]);
in
buildGoModule {
  pname = "ida-headless-mcp";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  vendorHash = "sha256-0nSdtEXImczGGQA8Lj0YQogK4R5li4wjikMg3oTFukE=";

  subPackages = [ "cmd/ida-mcp-server" ];

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    mkdir -p $out/share/ida-headless-mcp
    cp -r python proto $out/share/ida-headless-mcp/

    chmod +x $out/share/ida-headless-mcp/python/worker/server.py

    wrapProgram $out/bin/ida-mcp-server \
      --set-default IDA_MCP_WORKER "$out/share/ida-headless-mcp/python/worker/server.py" \
      --prefix PYTHONPATH : "$out/share/ida-headless-mcp/python/worker:$out/share/ida-headless-mcp/python/worker/gen:$out/share/ida-headless-mcp/proto:${ida-pro}/opt/idalib/python:${pythonEnv}/${python3.sitePackages}" \
      --prefix PATH : "${pythonEnv}/bin:${ida-pro}/opt" \
      --prefix LD_LIBRARY_PATH : "${ida-pro}/opt"
  '';

  meta = with lib; {
    description = "Headless IDA Pro binary analysis via Model Context Protocol";
    homepage = "https://github.com/zboralski/ida-headless-mcp";
    license = licenses.mit;
    mainProgram = "ida-mcp-server";
    platforms = [ "x86_64-linux" ];
  };
}
