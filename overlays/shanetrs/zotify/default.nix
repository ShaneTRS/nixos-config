{
  pkgs,
  fork ? "DraftKinner",
  ...
}:
with pkgs;
  python3Packages.buildPythonApplication rec {
    pname = "zotify";
    version = "1.1.1";

    pyproject = true;

    src = fetchFromGitHub {
      owner = fork;
      repo = pname;
      rev = "v${version}";
      hash = "sha256-VkYJsYVig/XDB7vyGHpv+61gIpgl3M+uz+/5SVQxEfw=";
    };

    patches = [./sanitize-filename.patch];
    postPatch = "export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python";
    postFixup = ''
      wrapProgram "$out/bin/zotify" --set PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION python
    '';

    build-system = [python3Packages.setuptools];

    pythonRelaxDeps = ["protobuf"];

    dependencies = with python3Packages; [
      ffmpy
      (music-tag.overrideAttrs (_: {
        src = fetchFromGitHub {
          owner = fork;
          repo = "music-tag";
          rev = "v0.4.7";
          hash = "sha256-FXyHqz9tHEdtkYNtmr/HdbSyR6DrQYgnWjxrqQ2prZ0=";
        };
      }))
      pillow
      tabulate
      tqdm
      (librespot.overrideAttrs (_: {
        src = fetchFromGitHub {
          owner = "kokarare1212";
          repo = "librespot-python";
          rev = "3b46fe560ad829b976ce63e85012cff95b1e0bf3";
          hash = "sha256-h34BNjaMeDzUeK0scyKoCpJHl9Hvvx/RZN7UWE0DMu0=";
        };
      }))
      pwinput
      protobuf
      limits
      pkce
    ];

    pythonImportsCheck = ["zotify"];

    meta = {
      description = "Fast and customizable music and podcast downloader";
      homepage = "https://github.com/${fork}/zotify";
      changelog = "https://github.com/${fork}/zotify/blob/main/CHANGELOG.md";
      mainProgram = "zotify";
    };
  }
