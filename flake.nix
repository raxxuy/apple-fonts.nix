{
  description = "Minimal Apple fonts from official Apple sources";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    sf-pro = {
      url = "https://devimages-cdn.apple.com/design/resources/download/SF-Pro.dmg";
      flake = false;
    };

    sf-compact = {
      url = "https://devimages-cdn.apple.com/design/resources/download/SF-Compact.dmg";
      flake = false;
    };

    sf-mono = {
      url = "https://devimages-cdn.apple.com/design/resources/download/SF-Mono.dmg";
      flake = false;
    };

    sf-arabic = {
      url = "https://devimages-cdn.apple.com/design/resources/download/SF-Arabic.dmg";
      flake = false;
    };

    sf-armenian = {
      url = "https://devimages-cdn.apple.com/design/resources/download/SF-Armenian.dmg";
      flake = false;
    };

    sf-georgian = {
      url = "https://devimages-cdn.apple.com/design/resources/download/SF-Georgian.dmg";
      flake = false;
    };

    sf-hebrew = {
      url = "https://devimages-cdn.apple.com/design/resources/download/SF-Hebrew.dmg";
      flake = false;
    };

    ny = {
      url = "https://devimages-cdn.apple.com/design/resources/download/NY.dmg";
      flake = false;
    };
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    let
      lib = nixpkgs.lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = lib.genAttrs systems;

      families = [
        "sf-pro"
        "sf-compact"
        "sf-mono"
        "sf-arabic"
        "sf-armenian"
        "sf-georgian"
        "sf-hebrew"
        "ny"
      ];

      mkPackages =
        pkgs:
        let
          mkFont =
            name:
            pkgs.stdenvNoCC.mkDerivation {
              pname = "apple-${name}";
              version = "1.0";

              src = inputs.${name};

              nativeBuildInputs = [
                pkgs._7zz
              ];

              dontUnpack = true;
              dontConfigure = true;
              dontBuild = true;

              installPhase = ''
                runHook preInstall

                mkdir -p extracted "$out/share/fonts"
                cd extracted

                7zz x "$src" -y >/dev/null

                for depth in 1 2 3 4 5; do
                  found=0

                  while IFS= read -r -d "" archive; do
                    found=1

                    directory="$(dirname "$archive")"
                    target="$directory/.unpacked-$(basename "$archive")"

                    mkdir -p "$target"

                    7zz x "$archive" -o"$target" -y >/dev/null || true
                    rm -f "$archive"
                  done < <(
                    find . -type f \( \
                      -iname '*.pkg' -o \
                      -name 'Payload' -o \
                      -name 'Payload~' \
                    \) -print0
                  )

                  if [ "$found" -eq 0 ]; then
                    break
                  fi
                done

                count=0

                while IFS= read -r -d "" font; do
                  filename="$(basename "$font")"
                  target="$out/share/fonts/$filename"

                  if [ -e "$target" ]; then
                    echo "Duplicate font filename: $filename" >&2
                    exit 1
                  fi

                  cp "$font" "$target"
                  count=$((count + 1))
                done < <(
                  find . -type f \( \
                    -iname '*.otf' -o \
                    -iname '*.ttf' -o \
                    -iname '*.ttc' \
                  \) -print0
                )

                if [ "$count" -eq 0 ]; then
                  echo "No fonts extracted from ${name}" >&2
                  exit 1
                fi

                runHook postInstall
              '';

              meta = {
                description = "Apple ${name} fonts";
                homepage = "https://developer.apple.com/fonts/";
                license = lib.licenses.unfree;
                platforms = lib.platforms.linux;
              };
            };

          individual = lib.genAttrs families mkFont;
        in
        individual
        // {
          default = pkgs.symlinkJoin {
            name = "apple-fonts";
            paths = lib.attrValues individual;
          };
        };

      fontOptions = {
        enable = lib.mkEnableOption "Apple fonts";

        families = lib.mkOption {
          type = lib.types.listOf (lib.types.enum families);
          default = [
            "sf-pro"
            "sf-mono"
          ];
          description = "Apple font families to install";
        };
      };
    in
    {
      packages = forAllSystems (
        system:
        mkPackages (
          import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          }
        )
      );

      nixosModules.default =
        { config, pkgs, ... }:
        let
          cfg = config.fonts.apple;
          packages = mkPackages pkgs;
        in
        {
          options.fonts.apple = fontOptions;

          config = lib.mkIf cfg.enable {
            fonts.packages = map (name: packages.${name}) cfg.families;
          };
        };

      homeManagerModules.default =
        { config, pkgs, ... }:
        let
          cfg = config.appleFonts;
          packages = mkPackages pkgs;
        in
        {
          options.appleFonts = fontOptions;

          config = lib.mkIf cfg.enable {
            home.packages = map (name: packages.${name}) cfg.families;

            fonts.fontconfig.enable = true;
          };
        };
    };
}
