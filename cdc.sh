
##
# If $REPO_DIRS isn't set, and ~/.cdcrc exists, source it now.
[[ -z $REPO_DIRS && -f $HOME/.cdcrc ]] && source $HOME/.cdcrc

##
# The actual function that the user calls from the command line.
#
# @param string $cd_dir
# @return void
cdc() {

    ##
    # Set local vars to avoid environment pollution.
    local dir
    local wdir
    local cd_dir="${1%%/*}"
    local USAGE="cdc: [DIRECTORY]"

    ##
    # NOTE: Experimental feature.
    # If arguemnt contains a slash, it's assumed to contain subdirectories.
    # This splits them into the directory root and its subdirectories.
    [[ "$1" == */* ]] && local subdir="${1#*/}"

    ##
    # Check for the existence of required variables that should be set in
    # ~/.cdcrc or a startup file. If not found, exit with non-zero return code.
    if (( ${#CDC_DIRS[@]} == 0 )); then
        echo "You must either \`export CDC_DIRS=()\` as an environmental" >&2
        echo "variable, or create a ~/.cdcrc file declaring the array!" >&2
        return 2
    ##
    # Print usage and exit if the wrong number of arguments are passed.
    elif (( $# != 1 )); then
        echo $USAGE >&2
        return 1
    fi

    ##
    # Loop through every element in $CDC_DIRS.
    for dir in ${CDC_DIRS[@]}; do
        ##
        # If a directory is in the $CDC_DIRS array, but the directory doesn't
        # exist, print a message to stderr and move on to the next directory in
        # the array.
        if ! [[ -d $dir ]]; then
            if ! $CDC_QUIET; then
                echo "[$dir] is listed in \$CDC_DIRS but is not a directory" >&2
            fi
            continue
        fi

        ##
        # If the element is not a directory, or is excluded, move on.
        ([[ ! -d $dir/$cd_dir ]] || _cdc_is_excluded_dir "$cd_dir") && continue

        ##
        # By this point, the parameter obviously exists as a directory, so we
        # save it to a variable.
        wdir="$dir/$cd_dir"

        ##
        # If the user passed a subdirectory (if the argument had a slash in it).
        if [[ -n $subdir ]]; then
            ##
            # If it exists as a directory, append it to the path.
            if [[ -d $wdir/$subdir ]]; then
                wdir+="/$subdir"
            else
                ##
                # If it doesn't exist as a directory, print message to stderr.
                if ! $CDC_QUIET; then
                    echo "[$subdir] does not exist in [$cd_dir]." >&2
                fi
            fi
        fi

        ##
        # Finally, cd to the path.
        cd "$wdir"

        ##
        # Return a successful code.
        return 0
    done

    ##
    # If no directory was found (the argument wasn't in the array), print
    # message to stderr and return unsuccessful code.
    echo "[$cd_dir] not found in ${CDC_DIRS[@]}" >&2
    return 2
}

