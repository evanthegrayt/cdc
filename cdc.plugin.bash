# `cd` to my repos in my repo directories. I decided to do this, rather than
# adding to $CDPATH, because I don't like changing the default `cd` behavior.
if [[ -n $BASH_IT ]]; then
    cite about-plugin
    about-plugin 'easily `cd` to common repos from anywhere'
fi

cdc() {

    [[ -z $REPO_DIRS && -f $HOME/.cdcrc ]] && source "$HOME/.cdcrc"

    local dir
    local wdir
    local cd_dir="${1%%/*}"
    local USAGE="cdc: [DIRECTORY]"

    [[ "$1" == */* ]] && local subdir="${1#*/}"

    if (( ${#CDC_DIRS[@]} == 0 )); then
        echo "You must either \`export CDC_DIRS=()\` as an environmental" >&2
        echo "variable, or create a ~/.cdcrc file declaring the array!" >&2
        return 2
    elif (( $# != 1 )); then
        echo $USAGE >&2
        return 1
    fi

    for dir in ${CDC_DIRS[@]}; do
        if ! [[ -d $dir ]]; then
            echo "[$dir] is exported in \$CDC_DIRS but is not a directory" >&2
            continue
        fi

        ([[ ! -d $dir/$cd_dir ]] || _cdc_is_excluded_dir "$cd_dir") && continue

        wdir="$dir/$cd_dir"

        if [[ -n $subdir ]]; then
            if [[ -d $wdir/$subdir ]]; then
                wdir+="/$subdir"
            else
                echo "[$subdir] does not exist in [$cd_dir]." >&2
            fi
        fi

        cd "$wdir"

        return 0
    done

    echo "[$cd_dir] not found in ${CDC_DIRS[@]}" >&2
    return 2
}

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

