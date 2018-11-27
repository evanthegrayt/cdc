#compdef cdc

_cdc_repo_list() {
    local dir

    [[ -e $HOME/.cdcrc ]] && source $HOME/.cdcrc

    for dir in ${REPO_DIRS[@]}; do
        cd $dir
        ls -d */ | tr -d "/"
    done
}

_arguments "1: :($( _cdc_repo_list ))"

