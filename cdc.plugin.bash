##
# The file to be sourced if you're using bash and want tab-completion.
# BASH_SOURCE points at this file even when it is sourced from another file.
CDC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

##
# Source the plugin and completion functions.
source "$CDC_DIR/cdc.sh"
unset CDC_DIR

##
# Bash-it plugin citations.
# ${BASH_IT:-} is safe under `set -u`; declare -F checks for bash functions.
if [[ -n ${BASH_IT:-} ]] \
    && declare -F cite >/dev/null \
    && declare -F about-plugin >/dev/null; then
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
    local parent_dirs
    local candidates
    local arg_count
    local candidate
    local args=()

    # Bash sets COMP_WORDS/COMP_CWORD when invoking a completion function.
    cur="${COMP_WORDS[COMP_CWORD]}"

    # Capture arguments before the word being completed, excluding the command.
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
        # compgen filters a word list to values matching the current word.
        COMPREPLY=( $( compgen -W "$(_cdc_completion_terminal_options) $(_cdc_completion_directory_options)" -- "$cur" ) )
        return 0
    fi

    # _cdc_completion_mode prints three whitespace-separated booleans.
    mode=($(_cdc_completion_mode "${args[@]}"))
    allow_ignored="${mode[0]}"
    repos_only="${mode[1]}"
    parent_dirs="${mode[2]}"
    candidates="$(_cdc_completion_list "$cur" "$allow_ignored" "$repos_only" "$parent_dirs")"

    # Bash reads completion candidates from COMPREPLY.
    COMPREPLY=()
    while IFS= read -r candidate; do
        [[ -n $candidate ]] || continue
        COMPREPLY+=("$candidate")
    done <<< "$candidates"
}

# Register _cdc_complete as the completion function for the cdc command.
complete -o nospace -F _cdc_complete cdc
