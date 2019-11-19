##
# If $REPO_DIRS isn't set, and ~/.cdcrc exists, source it now.
if [[ -z $REPO_DIRS && -f $HOME/.cdcrc ]]; then
    source $HOME/.cdcrc
fi

##
# Set the array that will remember the history.
CDC_HISTORY=()

##
# The actual function that the user calls from the command line.
# NOTE: I know this function is huge, and I hate it, but since this gets
# sourced into interactive shells, I try to pollute the users' environments
# with helper functions as little as possible.
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
    # In an interactive bash shell, you have to reset OPTIND each time, or
    # getopts only works the first time you use them for a function call.
    local OPTIND

    ##
    # NOTE: Experimental feature.
    # If argument contains a slash, it's assumed to contain subdirectories.
    # This splits them into the directory root and its subdirectories.
    if [[ "$1" == */* ]]; then
        local subdir="${1#*/}"
    fi

    ##
    # Check for the existence of required variables that should be set in
    # ~/.cdcrc or a startup file. If not found, exit with non-zero return code.
    if (( ${#CDC_DIRS[@]} == 0 )); then
        echo 'You must set `CDC_DIRS` in your configuration file!'  >&2
        return 2
    ##
    # Print usage and exit if the wrong number of arguments are passed.
    elif (( $# != 1 )); then
        echo 'USAGE: cdc [DIRECTORY]' >&2
        echo '  Use `-h` for more help' >&2
        return 1
    fi

    ##
    # Case options if present. Suppress errors because we'll supply our own.
    while getopts 'cdhlp' opt 2>/dev/null; do
        case $opt in

            ##
            # -c: cd to the root of the current repository in the stack.
            c)
                ##
                # If the stack is empty, tell the user and return.
                if (( ${#CDC_HISTORY[@]} == 0 )); then
                    echo 'Stack is empty.' >&2
                    return 1
                fi

                ##
                # cd to the root of the last repository in the history.
                cd ${CDC_HISTORY[-1]}

                return 0
                ;;

            ##
            # -l: cd to the last repo, but don't add it to the stack.
            # HACK: This reeks of code-smell, but arrays are awful in shell
            # scripts. If you can think of a better way to accomplish this,
            # please let me know. Just remember, it needs to be compatible with
            # both bash and zsh.
            l)
                local cdc_last_element
                local cdc_next_to_last_element

                ##
                # If the stack doesn't have at least two elements, tell the
                # user and return.
                if (( ${#CDC_HISTORY[@]} < 2 )); then
                    echo 'Not enough directories in the stack.' >&2
                    return 1
                fi

                ##
                # Flip the last two elements of the array.
                # HACK: When you unset an element in an array, it still exists;
                # it's just null, so you have to re-declare the array. If
                # anyone knows a better way, please let me know.
                cdc_last_element=${CDC_HISTORY[-1]}
                cdc_next_to_last_element=${CDC_HISTORY[-2]}
                unset 'CDC_HISTORY[-1]'
                CDC_HISTORY=(${CDC_HISTORY[@]})
                unset 'CDC_HISTORY[-1]'
                CDC_HISTORY=(
                    ${CDC_HISTORY[@]}
                    $cdc_last_element
                    $cdc_next_to_last_element
                )

                ##
                # Finally, cd to the last directory in the stack.
                cd ${CDC_HISTORY[-1]}

                return 0
                ;;

            ##
            # -d: List cdc history.
            d)
                local cdc_history

                ##
                # If the stack is empty, tell the user and return.
                if (( ${#CDC_HISTORY[@]} == 0 )); then
                    echo 'Stack is empty.'
                else
                    ##
                    # Print the array.
                    # echo ${CDC_HISTORY[@]}
                    for cdc_history in ${CDC_HISTORY[@]}; do
                        printf "${cdc_history##*/} "
                    done
                    echo
                fi

                return 0
                ;;

            ##
            # -p: cd to the last element in the stack and pop it from the array.
            p)
                ##
                # If the stack is empty, tell the user and return.
                if (( ${#CDC_HISTORY[@]} == 0 )); then
                    echo 'Stack is empty.' >&2
                    return 1
                elif (( ${#CDC_HISTORY[@]} == 1 )); then
                    echo 'At beginning of stack.' >&2
                    return 1
                fi

                ##
                # Unset the last element of the array, then re-declare it.
                # HACK: Again, this feels awful, but I can't get it to work for
                # both bash and zsh unless I do something like this.
                unset 'CDC_HISTORY[-1]'
                CDC_HISTORY=(${CDC_HISTORY[@]})

                ##
                # cd to the previous diretory in the stack.
                cd ${CDC_HISTORY[-1]}

                return 0
                ;;

            ##
            # -h: Print the help.
            h)
                echo 'USAGE: cdc [DIRECTORY]'
                echo '  -d | List the directories in stack'
                echo '  -c | `cd` to the current directory in the stack'
                echo '  -p | `cd` to previous directory and pop from the stack.'
                echo '  -l | Toggle between the last two directories in the stack'
                echo '  -h | Print this help'

                return 0
                ;;

            ##
            # If the option isn't supported, tell the user and exit.
            *)
                echo 'Invalid option.' >&2
                return 1
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
                echo "Warning: $dir is not a valid directory." >&2
            fi
            continue
        fi

        ##
        # If the element is not a directory, or is excluded, move on.
        if ([[ ! -d $dir/$cd_dir ]] || __cdc_is_excluded_dir "$cd_dir"); then
            continue
        fi

        ##
        # By this point, the parameter obviously exists as a directory, so we
        # save it to a variable.
        wdir="$dir/$cd_dir"

        ##
        # Add the directory to the history array.
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

##
# Returns "true" if argument is an element in $CDC_IGNORE.
#
# @param string $string
# @return boolean
__cdc_is_excluded_dir() {
    local string="$1"

    ##
    # If $CDC_IGNORE isn't defined or is empty, return "false".
    ([[ -z $CDC_IGNORE ]] || (( ${#CDC_IGNORE[@]} == 0 ))) && return 1

    ##
    # Loop through each element of $CDC_IGNORE array.
    for element in "${CDC_IGNORE[@]}"; do
        ##
        # If the element matches the passed string, return "true" to indicate
        # it's excluded.
        if [[ "${element/\//}" == "${string/\//}" ]]; then
            return 0
        fi
    done

    ##
    # If nothing matched, return "false".
    return 1
}

