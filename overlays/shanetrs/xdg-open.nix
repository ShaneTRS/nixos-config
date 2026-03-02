{
  xdg-utils,
  glib,
  ...
}:
xdg-utils.overrideAttrs (old: {
  postFixup =
    old.postFixup or ""
    + ''
      cat <<EOF > $out/bin/xdg-open
      #!/bin/sh
      ${glib}/bin/gio open "\$@" && exit
      for i in "\$@"; do
        ${glib}/bin/gdbus call --session \
          --dest org.freedesktop.portal.Desktop \
          --object-path /org/freedesktop/portal/desktop \
          --method org.freedesktop.portal.OpenURI.OpenURI \
          --timeout 5 \
          "" "\$i" '{"ask":<true>}' ||
        exit $?
      done
      EOF
    '';
})
