source "${0:h}/cdc.sh"
source "${0:h}/cdc_completion.sh"

_cdc() {
    _arguments "1: :($( _cdc_repo_list ))"
}

compdef '_cdc' cdc

