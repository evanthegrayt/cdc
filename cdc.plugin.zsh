##
# The file to be sourced if you're using zsh and want tab-completion.

##
# Source the plugin and completion functions.
source "${0:h}/cdc.sh"

##
# Add completion arguments.
_cdc() {
  _arguments -s \
    -D"[Debug mode for when unexpected things are happening]" \
    - help \
    -h"[Print this help]" \
    - no_other_args \
    -n"[cd to the current directory in the stack]" \
    -p"[cd to previous directory and pop from the stack]" \
    -t"[Toggle between the last two directories in the stack]" \
    -i"[List all directories that are to be ignored]" \
    -l"[List all directories that are cdc-able]" \
    -L"[List all directories in which to search]" \
    -d"[List the directories in stack]" \
    - allow_arg \
    -u"[Push the directory onto the stack]" \
    -U"[Do not push the directory onto the stack]" \
    -r"[Only cdc to repositories]" \
    -R"[cd to any directory, even it is not a repository]" \
    -a"[cd to the directory even if it is ignored]" \
    -w"[Print directory location instead of changing to it]" \
    1::"[Directory to cd]:($(_cdc_repo_list))"
}

##
# Define completions.
compdef '_cdc' cdc
