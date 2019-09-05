# Source the actual sh function
autoload -U compinit && compinit
source "${0:h}/cdc.plugin.bash"

_cdc_repo_list() {
    local dir
    local subdir

    [[ -z $REPO_DIRS && -f $HOME/.cdcrc ]] && source $HOME/.cdcrc

    for dir in "${CDC_DIRS[@]}"; do
        cd "$dir"
        for subdir in */; do
            if ! _cdc_is_excluded_dir "$subdir"; then
                echo "$subdir"
            fi
        done
    done
}

_cdc() {
    _arguments "1: :($( _cdc_repo_list ))"
}
compdef '_cdc' cdc
