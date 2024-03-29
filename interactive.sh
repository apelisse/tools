# This file should be sourced
# Just add `. .tools/interactive.sh` in ~/.bashrc for example

# Setup emacs
emacs=$(command -v emacs)
emacsclient=$(command -v emacsclient)

# Setup editor
if ! test -z "$emacs"
then
    if ! test -z $emacsclient
    then
        EDITOR="$emacsclient --quiet --alternate-editor='' --create-frame"
    else
        echo "Emacsclient is missing, using pure emacs ..." >&2
        EDITOR=$emacs
    fi
else
    echo "Emacs is missing, good luck..." >&2
    EDITOR=vi
fi

export EDITOR
alias e="\$EDITOR"

PAGER="bat -p"
export PAGER

se() {
    rg -p "$@" | $PAGER
}

alias bat="bat --style="changes,numbers""

alias sk="sk --ansi -i -c 'rg --color=always -i --line-number \"{}\"' --delimiter : --bind 'enter:execute-silent($EDITOR +{2} {1})'"

# Bind F1
bind '"\033OP":"sk\n"'

# Less colors
CLICOLOR=YesPlease
export CLICOLOR

# Prompt
PS1="\u@\h \w> "

HISTFILESIZE=2500

# Bash specific options
if test "${0##*bash}" == ""
then
    shopt -s histverify
fi
