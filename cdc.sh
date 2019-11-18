##
# If $REPO_DIRS isn't set, and ~/.cdcrc exists, source it now.
[[ -z $REPO_DIRS && -f $HOME/.cdcrc ]] && source $HOME/.cdcrc

##
# Set the array that will remember the history.
CDC_HISTORY=()

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
        echo "cdc: [DIRECTORY]" >&2
        return 1
    fi

    ##
    # Case options if they're present.
    while getopts "cdhlp" opts; do
        case $opts in

            ##
            # cd to the root of the current repository in the stack.
            c)
                ##
                # If the stack is empty, tell the user and return.
                if (( ${#CDC_HISTORY} == 0 )); then
                    echo "Stack is empty." >&2
                    return 1
                fi

                ##
                # cd to the root of the last repository in the history.
                cd ${CDC_HISTORY[-1]}

                return 0
                ;;

            ##
            # cd to the last repo, but don't add it to the stack.
            # HACK This reeks of code-smell, but arrays are awful in shell
            # scripts. If you can think of a better way, please let me know.
            l)

                local cdc_last_element
                local cdc_next_to_last_element

                ##
                # If the stack doesn't at least two elements, tell the user and
                # return.
                if (( ${#CDC_HISTORY} < 2 )); then
                    echo "Not enough directories in the stack." >&2
                    return 1
                fi

                cdc_last_element=${CDC_HISTORY[-1]}
                cdc_next_to_last_element=${CDC_HISTORY[-2]}

                ##
                # Unset the last element of the array.
                if [[ -n $BASH_VERSION ]]; then
                    unset 'CDC_HISTORY[${#CDC_HISTORY[@]}-1]'
                    unset 'CDC_HISTORY[${#CDC_HISTORY[@]}-2]'
                else # zsh
                    unset 'CDC_HISTORY[${#CDC_HISTORY[@]}]'
                    unset 'CDC_HISTORY[${#CDC_HISTORY[@]}-1]'
                fi

                CDC_HISTORY=(
                    ${CDC_HISTORY[@]}
                    $cdc_last_element
                    $cdc_next_to_last_element
                )

                cd ${CDC_HISTORY[-1]}

                return 0
                ;;

            ##
            # List cdc history.
            d)
                local cdc_history

                ##
                # If the stack is empty, tell the user and return.
                if (( ${#CDC_HISTORY} == 0 )); then
                    echo "Stack is empty."
                else
                    ##
                    # Print the array.
                    # echo ${CDC_HISTORY[@]}
                    for cdc_history in $CDC_HISTORY; do
                        printf "${cdc_history##*/} "
                    done
                    echo
                fi

                return 0
                ;;

            ##
            # cd to the last element in $CDC_HISTORY and pop it from the array.
            p)
                ##
                # If the stack is empty, tell the user and return.
                if (( ${#CDC_HISTORY} == 0 )); then
                    echo "Stack is empty." >&2
                    return 1
                elif (( ${#CDC_HISTORY} == 1 )); then
                    echo "At beginning of stack." >&2
                    return 1
                fi

                ##
                # Unset the last element of the array.
                if [[ -n $BASH_VERSION ]]; then
                    unset 'CDC_HISTORY[${#CDC_HISTORY[@]}-1]'
                else # zsh
                    unset 'CDC_HISTORY[${#CDC_HISTORY[@]}]'
                fi

                ##
                # HACK: When you unset an element in an array, it still exists;
                # it's just null, so you have to re-declare the array. If
                # anyone knows a better way, please let me know.
                CDC_HISTORY=($CDC_HISTORY)

                ##
                # cd to the previous diretory in the stack.
                cd ${CDC_HISTORY[-1]}

                return 0
                ;;

            ##
            # Print the help.
            h)
                echo "cdc: [DIRECTORY]" >&2

                return 0
                ;;
        esac
    done

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
        # Add the directory to the history array.
        if (( ${#CDC_HISTORY} > 0 )); then
            OLD_CDC_DIR=${CDC_HISTORY[-1]}
        fi
        CDC_HISTORY+=("$wdir")

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

