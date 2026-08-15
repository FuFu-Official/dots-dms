alias .. "cd .."
alias ... "cd ../.."
alias .... "cd ../../.."
alias ..... "cd ../../../.."

alias x clear

if type -q eza
    alias ls 'eza --icons --hyperlink'
    alias ll 'eza -l --icons --git --hyperlink'
    alias la 'eza -la --icons --git --hyperlink'
    alias lh 'eza -lah --icons --git --hyperlink'
    alias ld 'eza -l --icons --only-dirs --hyperlink'
    function lt
        eza --tree --level=$argv --icons --hyperlink
    end
    alias ltt 'eza --tree --level=2 --icons --hyperlink'
    alias lg 'eza -la --icons --git --git-ignore --hyperlink'
    alias lsize 'eza -lah --sort=size --hyperlink'
    alias ltime 'eza -lah --sort=modified --hyperlink'
else
    alias ls 'ls --hyperlink --color=auto'
    alias ll 'ls -lh'
    alias la 'ls -lah'
end

alias s sudo

# Editor
alias v nvim
alias vi nvim
alias V nvim

# Git
alias g git
alias ga "git add"
alias gcl "git clone"
alias gcm "git commit -m"
alias gst "git status"
alias gb "git branch"
alias gba "git branch -a"
alias gbd "git branch -D"
alias gcb "git checkout -b"
alias gph "git push"
alias gpl "git pull"

# Lazygit
alias gg lazygit

# Grep aliases
alias grep 'grep --color=auto'
alias fgrep 'fgrep --color=auto'
alias egrep 'egrep --color=auto'

# Long running command alert
function alert
    set -l exit_status $status

    set -l symbol "✅ [SUCCESS]"
    if test $exit_status -ne 0
        set symbol "❌ [FAILED ($exit_status)]"
    end

    notify-send --urgency=low "$symbol" "$history[1]"
end

alias rg 'rg --hyperlink-format=kitty'

# Time
alias d "date '+%Y-%m-%d %H:%M:%S'"

# Execute command in background without hangup
function nh
    nohup $argv >/dev/null 2>&1 &
    disown
end

# Coding
alias CC gcc
set -g FF_CXX_FLAGS \
    -Wall -Wextra -Weffc++ \
    -Werror=uninitialized \
    -Werror=return-type \
    -Wconversion -Wsign-compare \
    -Werror=unused-result \
    -Werror=suggest-override \
    -Wzero-as-null-pointer-constant \
    -Wmissing-declarations \
    -Wold-style-cast -Werror=vla \
    -Wnon-virtual-dtor \
    -Wlogical-op -Wduplicated-cond -Wduplicated-branches -Wformat=2

function CXX
    if test (count $argv) -eq 1
        set -l output (string replace -r '\.[^.]+$' '' -- $argv[1])
        g++ $FF_CXX_FLAGS $argv -o $output
        return
    end

    g++ $FF_CXX_FLAGS $argv
end

alias py python

function gf --description "Git add, commit and optionally push"

    # Default values
    set paths
    set message ""
    set force false

    function show_help
        echo "Usage: gf -m \"commit message\" [-p path1 path2 ...] [-f]"
        echo
        echo "Options:"
        echo "  -m MESSAGE    Commit message (required)"
        echo "  -p PATHS      Paths to add (can specify multiple, default: current directory)"
        echo "  -f            Force push without confirmation"
        echo "  -h            Show this help"
        echo
        echo "Examples:"
        echo "  gf -m \"Add new feature\""
        echo "  gf -p src/ docs/ -m \"Fix bug\""
        echo "  gf -f -m \"Update docs\" -p README.md src/main.js"
    end

    # Argument parsing
    set argv_copy $argv
    while test (count $argv_copy) -gt 0
        set arg $argv_copy[1]

        switch $arg
            case -m --message
                if test (count $argv_copy) -ge 2
                    set message $argv_copy[2]
                    set argv_copy $argv_copy[3..-1]
                else
                    echo "Error: Option $arg requires an argument." >&2
                    return 1
                end

            case -p --path
                set argv_copy $argv_copy[2..-1]
                while test (count $argv_copy) -gt 0
                    if string match -qr '^-' -- $argv_copy[1]
                        break
                    end
                    set paths $paths $argv_copy[1]
                    set argv_copy $argv_copy[2..-1]
                end

            case -f --force
                set force true
                set argv_copy $argv_copy[2..-1]

            case -h --help
                show_help
                return 0

            case '*'
                echo "Invalid option: $arg" >&2
                show_help
                return 1
        end
    end

    # Default path
    if test (count $paths) -eq 0
        set paths "."
    end

    # Validation
    if test -z "$message"
        echo "Error: commit message is required (-m)" >&2
        show_help
        return 1
    end

    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Error: Not in a git repository" >&2
        return 1
    end

    for path in $paths
        if not test -e $path
            echo "Error: Path '$path' does not exist" >&2
            return 1
        end
    end

    # Status
    set remote (git remote get-url origin 2>/dev/null; or echo "No remote")
    echo "Repository: $remote"
    echo "Branch: "(git branch --show-current)
    echo "Paths: $paths"
    echo "Message: $message"
    echo

    # Git add
    echo "Adding files..."
    for path in $paths
        echo "  Adding: $path"
        git add $path; or begin
            echo "Error: Failed to add '$path'" >&2
            return 1
        end
    end

    # Commit
    echo "Committing..."
    git commit -m "$message"; or begin
        echo "Error: Failed to commit" >&2
        return 1
    end

    # Push confirmation
    if test "$force" = false
        read -P "Push to remote? (y/N): " reply
        if not string match -iq y -- "$reply"; and test -n "$reply"
            echo "Commit created but not pushed"
            return 0
        end
    end

    # Push
    echo "Pushing..."
    git push; or begin
        echo "Error: Failed to push" >&2
        return 1
    end

    echo "✅ Successfully committed and pushed!"
end

# Git flow
alias gfm "gf -m"

# Shorin
abbr grub 'LANGUAGE=en_US.UTF-8 LANG=en_US.UTF-8 sudo grub-mkconfig -o /boot/grub/grub.cfg'
