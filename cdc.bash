# `cd` to my repos in my repo directories. I decided to do this, rather than
# adding to $CDPATH, because I don't like changing the default `cd` behavior.

cdc() {

    [[ -z $REPO_DIRS && -f $HOME/.cdcrc ]] && source $HOME/.cdcrc

    local dir
    local cd_dir="${1%%/*}"
    local USAGE="$0: [DIRECTORY]"

    if [[ "$1" == */* ]]; then
        local subdir="${1#*/}"
    fi

    if (( ${#CDC_DIRS[@]} == 0 )); then
        echo "You must either \`export CDC_DIRS=()\` as an environmental" >&2
        echo "variable, or create a ~/.cdcrc file declaring the array!" >&2
        return 2
    elif (( $# != 1 )); then
        echo $USAGE >&2
        return 1
    fi

    for dir in ${CDC_DIRS[@]}; do
        if [[ -d $dir ]]; then
            if [[ -d $dir/$cd_dir ]]; then
                cd "$dir/$cd_dir"
                if [[ -n $subdir ]]; then
                    if [[ -d $subdir ]]; then
                        cd "$subdir"
                    else
                        echo "[$subdir] does not exist in [$cd_dir]." >&2
                    fi
                fi
                return 0
            fi
        else
            echo "[$dir] is exported in \$CDC_DIRS but is not a directory" >&2
        fi
    done

    echo "[$cd_dir] not found in ${CDC_DIRS[@]}" >&2
    return 2
}

