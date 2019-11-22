##
# If $REPO_DIRS isn't set, and ~/.cdcrc exists, source it now.
if [[ -z $REPO_DIRS && -f $HOME/.cdcrc ]]; then
    source $HOME/.cdcrc
fi

##
# Set the array that will remember the history.
CDC_HISTORY=()

##
# The default files and directories that mark the root of a repository.
CDC_REPO_MARKERS+=(.git .git/ Rakefile Makefile .hg/ .bzr/ .svn/)

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
    local marker
    local debug=false
    local did_cd=false

    ##
    # The default for auto-push is true. The user can set `CDC_AUTO_PUSH=false`
    # in a startup file, and manually push with `-u`.
    local pushdir=${CDC_AUTO_PUSH:-true}
    local repos_only=${CDC_REPOS_ONLY:-false}

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
        echo 'You must set CDC_DIRS in a configuration file. See README.md.' >&2
        return 2
    fi

    ##
    # Case options if present. Suppress errors because we'll supply our own.
    while getopts 'DdcdhlrRptuU' opt 2>/dev/null; do
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

                did_cd=true
                ;;

            ##
            # -l: List the directories that are cdc-able.
            l)
                ##
                # Get the list of directories.
                local list=($( __cdc_repo_list $debug ))
                local directory

                ##
                # Print the list and pipe to column for nice output. Also pad
                # each element to make them all at least 8 characters long.
                # This is done because column has issues printing strings less
                # than 8 bytes.
                for directory in "${list[@]}"; do
                    printf "%-8s\n" "${directory}"
                done | column

                return 0
                ;;

            ##
            # -t: cd to the last repo, but don't add it to the stack.
            # HACK: This reeks of code-smell, but arrays are awful in shell
            # scripts. If you can think of a better way to accomplish this,
            # please let me know. Just remember, it needs to be compatible with
            # both bash and zsh.
            t)
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

                did_cd=true
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

                did_cd=true
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

                did_cd=true
                ;;

            ##
            # -r: Force cdc to only cd to repositories.
            r)
                repos_only=true
                ;;

            ##
            # -R: Force cdc to NOT only cd to repositories.
            R)
                repos_only=false
                ;;

            ##
            # -u: Push the directory onto the history stack.
            u)
                pushdir=true
                ;;

            ##
            # -U: Do not push the directory onto the history stack.
            U)
                pushdir=false
                ;;

            ##
            # -h: Print the help.
            h)
                echo 'USAGE: cdc [DIRECTORY]'
                echo '-l | List all directories that are cdc-able.'
                echo '-d | List the directories in stack'
                echo '-c | `cd` to the current directory in the stack'
                echo '-p | `cd` to previous directory and pop from the stack.'
                echo '-t | Toggle between the last two directories in the stack'
                echo "-D | Debug mode for when things aren't working properly"
                echo '-h | Print this help'

                return 0
                ;;

            ##
            # -D: Debug
            D)
                debug=true
                ;;

            ##
            # If the option isn't supported, tell the user and exit.
            *)
                echo 'Invalid option.' >&2
                return 1
                ;;
        esac
    done

    if $did_cd; then
        return 0
    fi

    ##
    # Shift out $OPTIND so we can accurately determine how many parameters (not
    # options) were passed. Then, set cd_dir to $1.
    shift $(( OPTIND - 1 ))
    local cd_dir="${1%%/*}"

    ##
    # Print usage and exit if the wrong number of arguments are passed.
    if (( $# != 1 )); then
        echo 'USAGE: cdc [DIRECTORY]' >&2
        echo '  Use `-h` for more help' >&2
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
            if $debug; then
                echo "DEBUG: $dir is not a valid directory." >&2
            fi
            continue
        fi

        ##
        # If the element is not a directory, or is excluded, move on.
        if ([[ ! -d $dir/$cd_dir ]] || __cdc_is_excluded_dir "$cd_dir"); then
            continue
        elif $repos_only; then
            if ! __cdc_is_repo_dir "$dir/$cd_dir"; then
                if $debug; then
                    echo "DEBUG: Match was found but it was not a repository."
                fi
                continue
            fi
        fi

        ##
        # By this point, the parameter obviously exists as a directory, so we
        # save it to a variable.
        wdir="$dir/$cd_dir"

        ##
        # Add the directory to the history array.
        if $pushdir; then
            CDC_HISTORY+=("$wdir")
        fi

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
                if $debug; then
                    echo "DEBUG: [$subdir] does not exist in [$cd_dir]." >&2
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

##
# Completion function for the cdc plugin that lists repositories found in
# $CDC_DIRS that aren't excluded.
#
# @param string $string
# @return array
__cdc_repo_list() {
    local dir
    local subdir
    local fulldir
    local directories=()
    local debug=${1:-false}

    ##
    # Loop through all elements of $CDC_DIRS array.
    for dir in "${CDC_DIRS[@]}"; do

        ##
        # If the element isn't a directory that exists, move on.
        if ! [[ -d $dir ]]; then
            if $debug; then
                echo "DEBUG: $dir is not a valid directory." >&2
            fi
            continue
        fi

        ##
        # Loop through all subdirectories in the directory.
        for fulldir in "$dir"/*/; do

            ##
            # Remove trailing slash from directory.
            subdir=${fulldir%?}

            ##
            # Remove preceding directories from subdir.
            subdir=${subdir##*/}

            if $CDC_REPOS_ONLY && ! __cdc_is_repo_dir "$fulldir"; then
                continue
            fi

            ##
            # If the directory isn't excluded, add it to the array.
            if ! __cdc_is_excluded_dir "$subdir"; then
                directories+=("$subdir")
            fi
        done
    done

    ##
    # "Return" the array.
    echo "${directories[@]}"
}

__cdc_is_repo_dir() {
    local dir="$1"
    local is_repo=1

    for marker in ${CDC_REPO_MARKERS[@]}; do
        if [[ $marker == */ && -d $dir/$marker ]] || \
            [[ $marker != */ && -f $dir/$marker ]]; then
                is_repo=0
                break
        fi
    done

    return $is_repo
}
