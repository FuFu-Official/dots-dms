if test -r /etc/os-release
    set -g OS linux
    set -g OS_ID ( grep '^ID=' /etc/os-release | cut -d= -f2 )
else
    set -g OS windows
    set -g OS_ID windows
end

# Arch Linux specific aliases
if test "$OS_ID" = arch

    set -gx HYPRSHOT_DIR $HOME/Pictures/Screenshots

    # Pacman
    alias p pacman
    alias sps "sudo pacman -S"
    alias spu "sudo pacman -Syu"
    alias spr "sudo pacman -Rns"

    # AUR
    if type -q yay
        alias g yay
        alias gu "yay -Syu"
        alias gs "yay -S"
        alias gr "yay -Rns"
    else if type -q paru
        alias g paru
        alias gu "paru -Syu"
        alias gs "paru -S"
        alias gr "paru -Rns"
    else
        echo "No AUR helper found (paru or yay)"
    end
end

# Kitty specific settings
if test "$TERM" = xterm-kitty
    function ssh --description "Aliasing ssh to kitty kitten for terminfo support"
        kitty +kitten ssh $argv
    end
end

