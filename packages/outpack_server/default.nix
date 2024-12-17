{ rustPlatform, fetchFromGitHub, lib, openssl, pkg-config }:
let
  sources = lib.importJSON ./sources.json;
in
rustPlatform.buildRustPackage rec {
  name = "outpack_server";
  src = fetchFromGitHub sources.src;
  cargoHash = sources.cargoDepsHash;

  buildInputs = [ openssl ];
  nativeBuildInputs = [ pkg-config ];

  VERGEN_GIT_SHA = src.rev;
}
