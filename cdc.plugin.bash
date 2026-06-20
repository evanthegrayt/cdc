##
# The file to be sourced if you're using bash and want tab-completion.
CDC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

##
# Source the plugin and completion functions.
source $CDC_DIR/cdc.sh
unset CDC_DIR

##
# Bash-it plugin citations.
if [[ -n $BASH_IT ]]; then
    cite about-plugin
    about-plugin '`cd` to directories from anywhere without changing $CDPATH'
fi

##
# Add completion arguments.
_cdc_complete() {
    local cur
    local mode
    local allow_ignored
    local repos_only
    local candidates
    local arg_count
    local args=()

    cur="${COMP_WORDS[COMP_CWORD]}"

    if (( COMP_CWORD > 1 )); then
        arg_count=$(( COMP_CWORD - 1 ))
        args=("${COMP_WORDS[@]:1:arg_count}")
    fi

    if _cdc_completion_has_terminal_action "${args[@]}"; then
        COMPREPLY=()
        return 0
    fi

    if _cdc_completion_has_operand "${args[@]}"; then
        COMPREPLY=()
        return 0
    fi

    if [[ $cur == -* ]]; then
        COMPREPLY=( $( compgen -W "$(_cdc_completion_terminal_options) $(_cdc_completion_directory_options)" -- "$cur" ) )
        return 0
    fi

    mode=($(_cdc_completion_mode "${args[@]}"))
    allow_ignored="${mode[0]}"
    repos_only="${mode[1]}"
    candidates="$(_cdc_completion_list "$cur" "$allow_ignored" "$repos_only")"

    COMPREPLY=( $( compgen -W "$candidates" -- "$cur" ) )
}

complete -o nospace -F _cdc_complete cdc
