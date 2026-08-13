rm -rf ~/.config/nvim
ln -s /home/fufu/dots-dms/config/nvim ~/.config/nvim

rm -rf ~/.config/matugen
ln -s /home/fufu/dots-dms/config/matugen ~/.config/matugen

# Only link this core config file without matugen generated theme files which are dynamically changed
rm -rf ~/.config/kitty/kitty.conf
ln -s /home/fufu/dots-dms/config/kitty/kitty.conf ~/.config/kitty/kitty.conf

rm -rf ~/.config/kitty/open-actions.conf
ln -s /home/fufu/dots-dms/config/kitty/open-actions.conf ~/.config/kitty/open-actions.conf

rm -rf ~/.config/fish
ln -s /home/fufu/dots-dms/config/fish ~/.config/fish

fcitx5-remote -e 2>/dev/null || true
sleep 1
rm -rf ~/.config/fcitx5
cp -a /home/fufu/dots-dms/config/fcitx5 ~/.config/fcitx5

rm -rf ~/.local/share/fcitx5/rime/default.custom.yaml
ln -s /home/fufu/dots-dms/config/fcitx5/rime/default.custom.yaml ~/.local/share/fcitx5/rime/default.custom.yaml
rime_deployer --build ~/.local/share/fcitx5/rime /usr/share/rime-data ~/.local/share/fcitx5/rime/build
fcitx5 -d

rm -rf ~/.config/starship.toml
ln -s /home/fufu/dots-dms/config/starship.toml ~/.config/starship.toml
