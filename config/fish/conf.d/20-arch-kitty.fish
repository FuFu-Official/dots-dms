if test -r /etc/os-release
    set -g OS linux
    set -g OS_ID ( grep '^ID=' /etc/os-release | cut -d= -f2 )
else
    set -g OS windows
    set -g OS_ID windows
end

# Arch Linux specific aliases
if test "$OS_ID" = arch
    # Pacman
    abbr p "sudo pacman"

    # AUR
    if type -q yay
        abbr g yay
    else if type -q paru
        abbr g paru
    end
end

# Kitty specific settings
if test "$TERM" = xterm-kitty
    function ssh --description "Aliasing ssh to kitty kitten for terminfo support"
        kitty +kitten ssh $argv
    end
end
