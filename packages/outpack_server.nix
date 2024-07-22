{ rustPlatform, fetchFromGitHub, lib, openssl, pkg-config }:
rustPlatform.buildRustPackage {
  name = "outpack_server";
  src = fetchFromGitHub (lib.importJSON ./outpack_server.json);
  cargoHash = "sha256-Mj6FZejSgNudoFvLpatRa+QgulluI7o4iWCxvMyU+L8=";

  buildInputs = [ openssl ];
  nativeBuildInputs = [ pkg-config ];
}
