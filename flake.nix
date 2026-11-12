{
  description = "A Nix flake for GitHub Desktop Plus";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      version = "3.6.11.0";

      sources = {
        x86_64-linux = {
          arch = "x86_64";
          hash = "e272e3970b09085638a9b56f08b8bb1fbe6d97146e83ffced6299270259ddcf9";
        };
        aarch64-linux = {
          arch = "arm64";
          # Run: nix store prefetch-file https://github.com/pol-rivero/github-desktop-plus/releases/download/v3.6.11.0/GitHubDesktopPlus-v3.6.11.0-linux-arm64.deb
          hash = "db10da6dfe97761dd0e3eb38182dc3ff704bf4e98fd8392558ce59a56f6aa8ca";
        };
      };

      supportedSystems = builtins.attrNames sources;
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          srcInfo = sources.${system};

          runtimeLibs = with pkgs; [
            alsa-lib
            at-spi2-atk
            at-spi2-core
            atk
            cairo
            cups
            dbus
            expat
            fontconfig
            freetype
            gdk-pixbuf
            glib
            gtk3
            libdrm
            libglvnd
            libnotify
            libsecret
            libuuid
            libxcb
            mesa
            nspr
            nss
            pango
            systemd
            libX11
            libXcomposite
            libXcursor
            libXdamage
            libXext
            libXfixes
            libXi
            libXrandr
            libXrender
            libXtst
            libxkbfile
            libxkbcommon
            wayland
            vulkan-loader
            libpulseaudio
            libjpeg8
            pipewire
            libei
          ];

          github-desktop-plus = pkgs.stdenv.mkDerivation {
            pname = "github-desktop-plus";
            inherit version;

            src = pkgs.fetchurl {
              url = "https://github.com/pol-rivero/github-desktop-plus/releases/download/v${version}/GitHubDesktopPlus-v${version}-linux-${srcInfo.arch}.deb";
              sha256 = srcInfo.hash;
            };

            nativeBuildInputs = with pkgs; [
              dpkg
              autoPatchelfHook
              makeWrapper
              wrapGAppsHook3
            ];

            buildInputs = runtimeLibs;

            autoPatchelfIgnoreMissingDeps = [
              "libc++.so.9.0"
              "libc++abi.so.6.0"
              "libpthread.so.26.1"
              "libm.so.10.1"
              "libc.musl-x86_64.so.1"
              "libc.musl-aarch64.so.1"
            ];

            unpackPhase = ''
              runHook preUnpack
              dpkg-deb --fsys-tarfile $src | tar -x --no-same-permissions --no-same-owner
              runHook postUnpack
            '';

            installPhase = ''
              runHook preInstall

              mkdir -p $out/bin
              cp -r usr/share $out/share
              cp -r usr/lib $out/lib

              # Replace bundled git with NixOS system git
              rm -rf $out/lib/github-desktop-plus/resources/app/git
              ln -s ${pkgs.git} $out/lib/github-desktop-plus/resources/app/git

              # Fix .desktop Exec path if present
              if [ -f $out/share/applications/github-desktop-plus.desktop ]; then
                substituteInPlace $out/share/applications/github-desktop-plus.desktop \
                  --replace-quiet "/usr/bin/github-desktop-plus" "$out/bin/github-desktop-plus" \
                  --replace-quiet "/usr/lib/github-desktop-plus/github-desktop-plus" "$out/bin/github-desktop-plus"
              fi

              makeWrapper $out/lib/github-desktop-plus/github-desktop-plus $out/bin/github-desktop-plus \
                --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath runtimeLibs}" \
                --add-flags "--no-sandbox --enable-features=UseOzonePlatform --ozone-platform-hint=auto"

              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "Fork of GitHub Desktop with extra features";
              homepage = "https://github.com/desktop-plus/desktop-plus";
              license = licenses.mit;
              platforms = supportedSystems;
              mainProgram = "github-desktop-plus";
            };
          };
        in
        {
          inherit github-desktop-plus;
          default = github-desktop-plus;
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/github-desktop-plus";
        };
      });

      overlays.default = final: prev: {
        github-desktop-plus = self.packages.${final.stdenv.hostPlatform.system}.default;
      };
    };
}
