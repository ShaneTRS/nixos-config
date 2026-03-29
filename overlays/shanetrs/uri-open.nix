{
  symlinkJoin,
  xdg-utils,
  glib,
  writeShellApplication,
  ...
}:
symlinkJoin {
  name = "uri-open";
  paths = [
    xdg-utils
    (writeShellApplication {
      name = "uri-open";
      runtimeInputs = [glib];
      text = ''
        gio open "$@" && exit
        for i in "$@"; do
          gdbus call --session \
          --dest org.freedesktop.portal.Desktop \
          --object-path /org/freedesktop/portal/desktop \
          --method org.freedesktop.portal.OpenURI.OpenURI \
          --timeout 5 \
          "" "$i" '{"ask":<true>}' ||
          exit $?
        done
      '';
    })
  ];
  postBuild = "ln -sf $out/bin/uri-open $out/bin/xdg-open";
}
