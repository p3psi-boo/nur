{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
}:
let
  gitCommit = "48995806bf1aa1c9c41bb8dff6b5ddd698539311";
in
buildGoModule (finalAttrs: {
  pname = "lazyssh";
  version = "unstable-2025-10-25";

  src = fetchFromGitHub {
    owner = "p3psi-boo";
    repo = "lazyssh";
    rev = gitCommit;
    hash = "sha256-/jywzjLZ51nSbiDbhw3H1eES3p0sZ9MSayGjJFQ+RKM=";
  };

  vendorHash = "sha256-OMlpqe7FJDqgppxt4t8lJ1KnXICOh6MXVXoKkYJ74Ks=";

  env.CGO_ENABLED = "0";

  ldflags = [
    "-s"
    "-w"
    "-X=main.version=${finalAttrs.version}"
    "-X=main.gitCommit=${gitCommit}"
  ];

  postInstall = ''
    mv $out/bin/cmd $out/bin/lazyssh
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Terminal-based SSH manager";
    homepage = "https://github.com/Adembc/lazyssh";
    changelog = "https://github.com/Adembc/lazyssh/commit/b5b34d7f0843a197a1fbe656689865aa10d0a84f";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ kpbaks ];
    mainProgram = "lazyssh";
  };
})
