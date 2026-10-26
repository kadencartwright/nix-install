{
  rustPlatform,
  tm-src,
}:

rustPlatform.buildRustPackage {
  pname = "tm";
  version = "0.1.0";

  src = tm-src;
  cargoLock.lockFile = "${tm-src}/Cargo.lock";
}
