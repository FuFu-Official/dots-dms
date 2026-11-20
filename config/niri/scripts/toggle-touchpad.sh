#!/bin/sh

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
file="$config_dir/touchpad-toggle.kdl"

if [ -s "$file" ]; then
  : >"$file" || exit 1
  message="Touchpad enabled"
else
  printf '%s\n' 'input {' '    touchpad {' '        off' '    }' '}' >"$file" || exit 1
  message="Touchpad disabled"
fi

notify-send --urgency=critical \
  --transient \
  --expire-time=3000 \
  --app-name=niri \
  --icon="$config_dir/icons/niri.svg" \
  "$message"
