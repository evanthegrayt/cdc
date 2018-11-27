# `cd` to my repos in my repo directories. I decided to do this, rather than
# adding to $CDPATH, because I don't like changing the default `cd` behavior.

cdc() {

    [[ -e $HOME/.cdcrc ]] && source $HOME/.cdcrc

    local dir
    local cd_dir="${1%%/*}"
    local USAGE="$0: [DIRECTORY]"

    if [[ "$1" == */* ]]; then
        local subdir="${1#*/}"
    fi

    if (( ${#REPO_DIRS[@]} == 0 )); then
        print "You must either \`export REPO_DIRS=()\` as an environmental" >&2
        print "variable, or create a ~/.cdcrc file declaring the array!" >&2
        return 2
    elif (( $# != 1 )); then
        print $USAGE >&2
        return 1
    fi

    for dir in ${REPO_DIRS[@]}; do
        if [[ -d $dir ]]; then
            if [[ -d $dir/$cd_dir ]]; then
                cd "$dir/$cd_dir"
                if [[ -n $subdir ]]; then
                    if [[ -d $subdir ]]; then
                        cd "$subdir"
                    else
                        print "[$subdir] does not exist in [$cd_dir]." >&2
                    fi
                fi
                return 0
            fi
        else
            print "[$dir] is exported in \$REPO_DIRS but is not a directory" >&2
        fi
    done

    print "[$cd_dir] not found in ${REPO_DIRS[@]}" >&2
    return 2
}

