{
  buildGoModule,
  tm-src,
}:

buildGoModule {
  pname = "tm";
  version = "0-unstable";

  src = tm-src;
  vendorHash = "sha256-6yCXfcOIlbPJrRkGIoed58kQb0XF/KGcpzELXXPlNs0=";

  ldflags = [
    "-s"
    "-w"
  ];
}
