{pkgs, ...}:
with pkgs;
  python3Packages.buildPythonApplication {
    pname = "zotify";
    version = "0.6.13";

    pyproject = true;

    src = fetchFromGitHub {
      owner = "zotify-dev";
      repo = "zotify";
      # repository has no version tags
      # https://github.com/zotify-dev/zotify/issues/124
      rev = "5da27d32a1f522e80a3129c61f939b1934a0824a";
      hash = "sha256-KA+Q4sk+riaFTybRQ3aO5lgPg4ECZE6G+By+x2uP/VM=";
    };

    patches = [./ffmpeg-args.patch ./sanitize-filename.patch];
    postFixup = ''
      wrapProgram "$out/bin/zotify" --set PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION python
    '';

    build-system = [python3Packages.setuptools];

    pythonRelaxDeps = ["protobuf"];

    dependencies = with python3Packages; [
      ffmpy
      music-tag
      pillow
      tabulate
      tqdm
      (librespot.overrideAttrs (_: {
        src = fetchFromGitHub {
          owner = "kokarare1212";
          repo = "librespot-python";
          rev = "3a6ce32d0d1aa69a3f6f957ad2e35cdd7ddbc278";
          hash = "sha256-AsMEHb/WNLVNIVoCyOaBytG8p4QoZwRamk87BoNO1EY=";
        };
      }))
      pwinput
      protobuf
    ];

    pythonImportsCheck = ["zotify"];

    meta = {
      description = "Fast and customizable music and podcast downloader";
      homepage = "https://github.com/zotify-dev/zotify";
      changelog = "https://github.com/zotify-dev/zotify/blob/main/CHANGELOG.md";
      license = lib.licenses.zlib;
      mainProgram = "zotify";
      maintainers = with lib.maintainers; [bwkam];
    };
  }
# zotify.overrideAttrs (old: {
#   patches = [./ffmpeg-args.patch ./sanitize-filename.patch];
#   dependencies =
#     old.passthru.dependencies
#     ++ [
#       (python3Packages.librespot.overrideAttrs (_: {
#         src = fetchFromGitHub {
#           owner = "kokarare1212";
#           repo = "librespot-python";
#           rev = "3a6ce32d0d1aa69a3f6f957ad2e35cdd7ddbc278";
#           hash = "sha256-AsMEHb/WNLVNIVoCyOaBytG8p4QoZwRamk87BoNO1EY=";
#         };
#       }))
#     ];
#   postFixup =
#     old.postFixup
#     + ''
#       wrapProgram "$out/bin/zotify" --set PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION python
#     '';
# })

