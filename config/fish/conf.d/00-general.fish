set -gx EDITOR nvim
set -gx TERMINAL kitty

# Commands to run in interactive sessions can go here
set -gx fish_key_bindings fish_vi_key_bindings

function fish_user_key_bindings
    # bind jk to return to normal mode
    bind -M insert -m default jk backward-char force-repaint

    bind -M visual -m default q end-selection force-repaint
end

function fish_mode_prompt
end

bind -M insert ctrl-y accept-autosuggestion
bind -M insert ctrl-alt-y forward-word

if set -q CONTAINER_ID; or test -e /run/.containerenv
    set -g IS_DISTROBOX 1
else
    set -g IS_DISTROBOX 0
end

# Rust
set -px PATH /home/fufu/.cargo/bin

# Set Proxy for GO Dependency
set -Ux GOPROXY https://goproxy.cn,direct

# Node
fnm env --use-on-cd --shell fish | source
set -gx nvm_default_version lts

# Starship
starship init fish | source

# thefuck
thefuck --alias fk | source

# zoxide
zoxide init fish | source
alias cd z

# Qt
set -gx QT_QPA_PLATFORMTHEME qt6ct

function proxy_on
    set -gx http_proxy http://127.0.0.1:7892
    set -gx https_proxy http://127.0.0.1:7892
    set -gx all_proxy socks5://127.0.0.1:7890
    # Ignore no_proxy address
    set -gx no_proxy localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12
    echo "Proxy enabled."
end

function proxy_off
    set -e http_proxy
    set -e https_proxy
    set -e all_proxy
    set -e no_proxy
    echo "Proxy disabled."
end
