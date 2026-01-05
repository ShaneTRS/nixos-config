{
  python3Packages,
  fetchFromGitHub,
  fork ? "DraftKinner",
  version ? "acde75fa4935bb90ef43b4b29b9e2a25ab6636f3",
  hash ? "sha256-/BeePdA6/1oyxf2F4K5iQDWK5qy1eTipiTvHcMVWmgU=",
  ...
}:
python3Packages.buildPythonApplication rec {
  pname = "zotify";
  inherit version;

  pyproject = true;

  src = fetchFromGitHub {
    owner = fork;
    repo = pname;
    rev = "${version}";
    inherit hash;
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
    librespot
    # (librespot.overrideAttrs (_: {
    #   src = fetchFromGitHub {
    #     owner = "kokarare1212";
    #     repo = "librespot-python";
    #     rev = "3b46fe560ad829b976ce63e85012cff95b1e0bf3";
    #     hash = "sha256-h34BNjaMeDzUeK0scyKoCpJHl9Hvvx/RZN7UWE0DMu0=";
    #   };
    #  # pythonRelaxDeps = ["protobuf"];
    # }))
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
