#!/bin/sh
PATH="$PATH:/run/current-system/sw/bin"

[ -f "$HOME/.config/xfce4/chicago95" ] && exit
cd "$(dirname "$0")" || exit

# shellcheck disable=SC3028
WORK_DIR="/tmp/win95-$RANDOM"
mkdir -p "$WORK_DIR"

# shellcheck disable=SC1091
. ./theme.ini
xfconf-query -c xsettings -p /Net/ThemeName -n -t string -s "$GTK_THEME"
xfconf-query -c xfwm4 -p /general/theme -n -t string -s "$WM_THEME"
xfconf-query -c xfwm4 -p /general/button_layout -n -t string -s "$WM_BUTTON_LAYOUT"
[ -n "$WM_TITLE_FONT" ] && xfconf-query -c xfwm4 -p /general/title_font -n -t string -s "$WM_TITLE_FONT"
xfconf-query -c xsettings -p /Net/IconThemeName -n -t string -s "$ICON_THEME"
xfconf-query -c xsettings -p /Gtk/CursorThemeName -n -t string -s "$CURSOR_THEME"
xfconf-query -c xsettings -p /Gtk/FontName -n -t string -s "$FONT"
[ -n "$MONOSPACE_FONT" ] && xfconf-query -c xsettings -p /Gtk/MonospaceFontName -n -t string -s "$MONOSPACE_FONT"
[ -n "$DECORATION_LAYOUT" ] && xfconf-query -c xsettings -p /Gtk/DecorationLayout -n -t string -s "$DECORATION_LAYOUT"
# xfconf-query -c xfwm4 -p /general/workspace_count -s "$WORKSPACE_COUNT"

xfconf-query -c xsettings -p /Gtk/CursorThemeName -n -t "string" -s "Chicago95_Cursor_Black"

sed "s:\$HOME:$HOME:g" "icons.screen.latest.rc" > "$HOME/.config/xfce4/desktop/icons.screen.latest.rc"
install -m755 Desktop/* "$HOME/Desktop"

xfce4-panel-profiles load panel-profile.tar.bz2
cp version "$HOME/.config/xfce4/chicago95"