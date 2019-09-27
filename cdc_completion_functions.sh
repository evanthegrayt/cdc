_cdc_is_excluded_dir() {
    local string="$1"

    ([[ -z $CDC_IGNORE ]] || (( ${#CDC_IGNORE[@]} == 0 ))) && return 1

    for element in "${CDC_IGNORE[@]}"; do
        if [[ "${element/\//}" == "${string/\//}" ]]; then
            return 0
        fi
    done

    return 1
}

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
