#!/bin/sh

file="$HOME/.config/niri/touchpad-toggle.kdl"

if [ -s "$file" ]; then
  : >"$file"
  notify-send "Touchpad enabled"
else
  printf '%s\n' 'input {' '    touchpad {' '        off' '    }' '}' >"$file"
  notify-send "Touchpad disabled"
fi
