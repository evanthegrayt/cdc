source "${0:h}/cdc.sh"
source "${0:h}/cdc_completion_functions.sh"
autoload -U compinit && compinit

_cdc() {
    _arguments "1: :($( _cdc_repo_list ))"
}

compdef '_cdc' cdc

