{ rustPlatform, fetchFromGitHub, lib, openssl, pkg-config }:
rustPlatform.buildRustPackage {
  name = "outpack_server";
  src = fetchFromGitHub (lib.importJSON ./sources.json);
  cargoHash = "sha256-4Jf5L+JUetHqYslVpHQOyXEpZvAIE5zD3f+2xeGhkoU=";

  buildInputs = [ openssl ];
  nativeBuildInputs = [ pkg-config ];
}
