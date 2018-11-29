#compdef cdc

_cdc_repo_list() {
    local dir

    [[ -z $REPO_DIRS && -f $HOME/.cdcrc ]] && source $HOME/.cdcrc

    for dir in ${CDC_DIRS[@]}; do
        cd $dir
        ls -d */ | tr -d "/"
    done
}

_arguments "1: :($( _cdc_repo_list ))"

