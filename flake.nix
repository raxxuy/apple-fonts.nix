{
  description = "Apple fonts packaged for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        {
          apple-fonts = pkgs.stdenv.mkDerivation {
            pname = "apple-fonts";
            version = "1.0";

            src = pkgs.fetchurl {
              url = "https://github.com/gxanshu/otf-apple-fonts/releases/download/Fonts/fonts.zip";
              sha256 = "8a6d9d53019aa52c1b7be6c0a07cadbc0ff9929d3b8945f7fcee9ee519d900fe";
            };

            nativeBuildInputs = [ pkgs.unzip ];

            unpackPhase = ''
              unzip $src
            '';

            installPhase = ''
              mkdir -p $out/share/fonts/opentype
              find . -type f -name '*.otf' -exec install -Dm644 {} $out/share/fonts/opentype/{} \;
            '';

            meta = with pkgs.lib; {
              description = "Apple system fonts";
              license = licenses.unfree;
              platforms = platforms.all;
            };
          };

          default = self.packages.${system}.apple-fonts;
        });

      nixosModules.default = { config, lib, pkgs, ... }: {
        options.fonts.apple = {
          enable = lib.mkEnableOption "Apple fonts";
        };

        config = lib.mkIf config.fonts.apple.enable {
          fonts.packages = [ self.packages.${pkgs.system}.apple-fonts ];
        };
      };

      homeManagerModules.default = { config, lib, pkgs, ... }: {
        options.fonts.apple = {
          enable = lib.mkEnableOption "Apple fonts";
        };

        config = lib.mkIf config.fonts.apple.enable {
          home.packages = [ self.packages.${pkgs.system}.apple-fonts ];
          fonts.fontconfig.enable = true;
        };
      };
    };
}
