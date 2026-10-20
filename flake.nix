{
  description = "Paat's Dranklijst development shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              # Same minor as the version pinned in .github/workflows/release.yml.
              flutter347

              # `flutter build linux` / `flutter run -d linux`.
              cmake
              ninja
              clang
              pkg-config
              gtk3
            ];
          };
        }
      );
    };
}
