##
# The file to be sourced if you're using zsh and want tab-completion.

##
# Source the plugin and completion functions.
source "${0:h}/cdc.sh"

##
# Add completion arguments.
_cdc() {
    _arguments "1: :($( _cdc_repo_list ))"
}

##
# Define completions.
compdef '_cdc' cdc

