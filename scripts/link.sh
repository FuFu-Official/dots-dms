#!/usr/bin/env bash
set -e

DOTS_PREFIX="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$HOME/.config"

rm -rf "$HOME/.config/nvim"
ln -s "$DOTS_PREFIX/config/nvim" "$HOME/.config/nvim"

rm -rf "$HOME/.config/fish"
ln -s "$DOTS_PREFIX/config/fish" "$HOME/.config/fish"

rm -rf "$HOME/.config/matugen"
ln -s "$DOTS_PREFIX/config/matugen" "$HOME/.config/matugen"

rm -rf "$HOME/.config/kitty"
ln -s "$DOTS_PREFIX/config/kitty" "$HOME/.config/kitty"

rm -rf "$HOME/.config/niri"
ln -s "$DOTS_PREFIX/config/niri" "$HOME/.config/niri"

rm -rf "$HOME/.config/zathura"
ln -s "$DOTS_PREFIX/config/zathura" "$HOME/.config/zathura"

rm -rf "$HOME/.config/DankMaterialShell"
ln -s "$DOTS_PREFIX/config/DankMaterialShell" "$HOME/.config/DankMaterialShell"

rm -rf "$HOME/.config/starship.toml"
ln -s "$DOTS_PREFIX/config/starship.toml" "$HOME/.config/starship.toml"
