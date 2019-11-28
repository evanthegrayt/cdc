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
    # The default files and directories that mark the root of a repository.
    # This is set before `~/.cdcrc` is sourced so the user can overwrite OR
    # append to it from their config file.
    CDC_REPO_MARKERS=(.git/ .git Rakefile Makefile .hg/ .bzr/ .svn/)

    ##
    # If $REPO_DIRS isn't set, and ~/.cdcrc exists, source it now.
    if [[ -f $HOME/.cdcrc ]]; then
        source $HOME/.cdcrc
    fi

    ##
    # Set local vars to avoid environment pollution.
    local dir
    local list
    local directory
    local wdir
    local marker
    local cdc_last_element
    local cdc_next_to_last_element
    local cdc_history
    local rc=0
    local cdc_list_dirs=false
    local cdc_list_searched_dirs=false
    local cdc_toggle=false
    local debug=false
    local should_return=false
    local allow_ignored=false
    local cdc_current=false
    local cdc_pop=false
    local cdc_show_history=false
    local cdc_list_ignored=false
    local print_help=false
    local use_color=${CDC_COLOR:-true}

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
        _cdc_error 'You must set CDC_DIRS in a ~/.cdcrc file. See README.md.'
        return 1
    fi

    ##
    # Case options if present. Suppress errors because we'll supply our own.
    while getopts 'acCDdndhilLrRptuU' opt 2>/dev/null; do
        case $opt in

            ##
            # -a: Allow cd-ing to ignored directories.
            a) allow_ignored=true ;;

            ##
            # -c: Enable color.
            c) use_color=true ;;

            ##
            # -C: Disable color.
            C) use_color=false ;;

            ##
            # -n: cd to the root of the current repository in the stack.
            n) cdc_current=true ;;

            ##
            # -l: List the directories that are cdc-able.
            l) cdc_list_dirs=true ;;

            ##
            # -i: List the directories that are ignored.
            i) cdc_list_ignored=true ;;

            ##
            # -L: List the directories that are searched.
            L) cdc_list_searched_dirs=true ;;

            ##
            # -t: cd to the last repo, but don't add it to the stack.
            t) cdc_toggle=true ;;

            ##
            # -d: List cdc history.
            d) cdc_show_history=true ;;

            ##
            # -p: cd to the last element in the stack and pop it from the array.
            p) cdc_pop=true ;;

            ##
            # -r: Force cdc to only cd to repositories.
            r) repos_only=true ;;

            ##
            # -R: Force cdc to NOT only cd to repositories.
            R) repos_only=false ;;

            ##
            # -u: Push the directory onto the history stack.
            u) pushdir=true ;;

            ##
            # -U: Do not push the directory onto the history stack.
            U) pushdir=false ;;

            ##
            # -D: Debug
            D) debug=true ;;

            ##
            # -h: Print the help.
            h) print_help=true ;;

            ##
            # If the option isn't supported, tell the user and exit.
            *)
                _cdc_print 'error' 'Invalid option.' $debug
                return 1
                ;;
        esac
    done

    ##
    # If colors are enabled, set color values if they're not already set.
    if $use_color; then
        : ${CDC_ERROR_COLOR:='\e[0;91m'}
        : ${CDC_SUCCESS_COLOR:='\e[0;92m'}
        : ${CDC_WARNING_COLOR:='\e[0;93m'}
        CDC_RESET='\e[0m'
    ##
    # If colors are not enabled, unset the color variables.
    else
        unset CDC_ERROR_COLOR CDC_SUCCESS_COLOR CDC_WARNING_COLOR CDC_RESET
    fi

    if $print_help; then
        printf "${CDC_SUCCESS_COLOR}USAGE: cdc [DIRECTORY]$CDC_RESET"
        printf "${CDC_WARNING_COLOR}\n\n"
        printf 'Options will always override variables set in ~/.cdcrc!'
        printf "${CDC_RESET}\n"
        printf "  ${CDC_WARNING_COLOR}-a${CDC_RESET}"
        echo ' | `cd` to the directory even if it is ignored.'
        printf "  ${CDC_WARNING_COLOR}-l${CDC_RESET}"
        echo ' | List all directories that are cdc-able.'
        printf "  ${CDC_WARNING_COLOR}-L${CDC_RESET}"
        echo ' | List all directories in which to search.'
        printf "  ${CDC_WARNING_COLOR}-i${CDC_RESET}"
        echo ' | List all directories that are to be ignored.'
        printf "  ${CDC_WARNING_COLOR}-d${CDC_RESET}"
        echo ' | List the directories in stack.'
        printf "  ${CDC_WARNING_COLOR}-n${CDC_RESET}"
        echo ' | `cd` to the current directory in the stack.'
        printf "  ${CDC_WARNING_COLOR}-p${CDC_RESET}"
        echo ' | `cd` to previous directory and pop from the stack.'
        printf "  ${CDC_WARNING_COLOR}-t${CDC_RESET}"
        echo ' | Toggle between the last two directories in the stack.'
        printf "  ${CDC_WARNING_COLOR}-u${CDC_RESET}"
        echo ' | Push the directory onto the stack.'
        printf "  ${CDC_WARNING_COLOR}-U${CDC_RESET}"
        echo ' | Do not push the directory onto the stack'
        printf "  ${CDC_WARNING_COLOR}-r${CDC_RESET}"
        echo ' | 'Only cdc to repositories.
        printf "  ${CDC_WARNING_COLOR}-R${CDC_RESET}"
        echo ' | cd to any directory, even it is not a repository.'
        printf "  ${CDC_WARNING_COLOR}-D${CDC_RESET}"
        echo ' | Debug mode for when unexpected things are happening.'
        printf "  ${CDC_WARNING_COLOR}-h${CDC_RESET}"
        echo ' | Print this help.'

        return 0
    fi

    if $debug; then
        echo "========================= ENV ==========================="
        printf "CDC_DIRS         += ${CDC_SUCCESS_COLOR}%s$CDC_RESET\n"\
            "${CDC_DIRS[@]}"
        printf "CDC_IGNORE       += ${CDC_WARNING_COLOR}%s$CDC_RESET\n"\
            "${CDC_IGNORE[@]}"
        echo
        printf "CDC_AUTO_PUSH     = %s\n" \
            $( _cdc_print 'boolean' $CDC_AUTO_PUSH )
        printf "CDC_REPOS_ONLY    = %s\n" \
            $( _cdc_print 'boolean' $CDC_REPOS_ONLY )
        printf "CDC_COLOR         = %s\n" \
            $( _cdc_print 'boolean' $CDC_COLOR )
        echo
        printf "CDC_SUCCESS_COLOR = $CDC_SUCCESS_COLOR%s$CDC_RESET\n"\
            "$CDC_SUCCESS_COLOR"
        printf "CDC_WARNING_COLOR = $CDC_WARNING_COLOR%s$CDC_RESET\n"\
            "$CDC_WARNING_COLOR"
        printf "CDC_ERROR_COLOR   = $CDC_ERROR_COLOR%s$CDC_RESET\n"\
            "$CDC_ERROR_COLOR"
        echo "======================= RUNTIME ========================="
    fi

    if $cdc_list_searched_dirs; then
        if $debug; then
            _cdc_print 'success' 'Listing searched directories.' $debug
        fi
        printf "%s\n" "${CDC_DIRS[@]}" | column
        should_return=true
    fi

    if $cdc_list_dirs; then
        if $debug; then
            _cdc_print 'success' 'Listing available directories.' $debug
        fi
        ##
        # Get the list of directories.
        list=($( _cdc_repo_list $debug ))

        ##
        # Print the list and pipe to column for nice output. Also pad
        # each element to make them all at least 8 characters long.
        # This is done because column has issues printing strings less
        # than 8 bytes.
        printf "%-8s\n" "${list[@]}" | column

        should_return=true
    fi

    if $cdc_toggle; then
        ##
        # If the stack doesn't have at least two elements, tell the user.
        if (( ${#CDC_HISTORY[@]} < 2 )); then
            _cdc_print 'error' 'Not enough directories in the stack.' $debug
            (( rc++ ))
        else
            if $debug; then
                _cdc_print 'success' 'Toggling between last two directories.' \
                    $debug
            fi

            ##
            # Flip the last two elements of the array.
            # HACK: When you unset an element in an array, it still exists; it's
            # just null, so you have to re-declare the array. If anyone knows a
            # better way, please let me know.
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

        fi

        should_return=true
    fi

    if $cdc_list_ignored; then
        ##
        # If the ignore array is empty, return.
        if (( ${#CDC_IGNORE[@]} == 0 )); then
            if $debug; then
                _cdc_print 'warn' 'No directories are being ignored.' $debug
            fi
        else
            if $debug; then
                _cdc_print 'success' 'Listing ignored directories.' $debug
            fi

            printf "%s\n" "${CDC_IGNORE[@]}" | column
        fi

        should_return=true
    fi

    if $cdc_show_history; then
        ##
        # If the stack is empty, tell the user.
        if (( ${#CDC_HISTORY[@]} == 0 )); then
            _cdc_print 'error' 'Stack is empty.' $debug
            (( rc++ ))
        else

            if $debug; then
                _cdc_print 'success' 'Listing directories in history.' $debug
            fi

            ##
            # Print the array.
            for cdc_history in ${CDC_HISTORY[@]}; do
                printf "${cdc_history##*/} "
            done
            echo
        fi

        should_return=true
    fi

    if $cdc_current; then
        ##
        # If the stack is empty, tell the user.
        if (( ${#CDC_HISTORY[@]} == 0 )); then
            _cdc_print 'error' "Stack is empty." $debug
            (( rc++ ))
        else
            if $debug; then
                _cdc_print 'success' \
                    'Changing to current directory in history.' $debug
            fi

            ##
            # cd to the root of the last repository in the history.
            cd ${CDC_HISTORY[-1]}
        fi

        should_return=true
    fi

    if $cdc_pop; then
        ##
        # If there aren't enough directories to pop, notify the user.
        if (( ${#CDC_HISTORY[@]} == 0 )); then
            _cdc_print 'error' 'Stack is empty.' $debug
            (( rc++ ))
        elif (( ${#CDC_HISTORY[@]} == 1 )); then
            _cdc_print 'error' 'At beginning of stack.' $debug
            (( rc++ ))
        else
            if $debug; then
                _cdc_print 'success' 'Changing to last directory in history.' \
                    $debug
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
        fi

        should_return=true
    fi

    ##
    # If we did an action that already caused us to `cd`, return.
    if $should_return; then
        return $rc
    fi

    ##
    # Shift out $OPTIND so we can accurately determine how many parameters (not
    # options) were passed. Then, set cd_dir to $1.
    shift $(( OPTIND - 1 ))
    local cd_dir="${1%%/*}"

    ##
    # Print usage and exit if the wrong number of arguments are passed.
    if (( $# != 1 )); then
        _cdc_print 'error' 'USAGE: cdc [DIRECTORY]' $debug
        _cdc_print 'error' '  Use `-h` for more help' $debug
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
                _cdc_print 'warn' \
                    "$dir is in CDC_REPO_DIRS but isn't a directory." $debug
            fi
            continue
        fi

        ##
        # If the element is not a directory, skip it.
        if [[ ! -d $dir/$cd_dir ]]; then
            continue

        ##
        # If the directory exists, but is excluded, skip it.
        elif ! $allow_ignored && _cdc_is_excluded_dir "$cd_dir"; then
            if $debug; then
                _cdc_print 'warn' 'Match was found but it is ignored.' $debug
            fi
            continue

        ##
        # If the directory exists, but we're in repos-only mode and the
        # directory isn't a repo, skip it.
        elif $repos_only && ! _cdc_is_repo_dir "$dir/$cd_dir"; then
            if $debug; then
                _cdc_print 'warn' \
                    'Match was found but it is not a repository.' $debug
            fi
            continue
        fi

        ##
        # By this point, the parameter obviously exists as a valid directory,
        # so we save it to a variable.
        wdir="$dir/$cd_dir"

        ##
        # If pushdir is true, add the directory to the history stack.
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
                    _cdc_print 'warn' "$subdir does not exist in $cd_dir." \
                        $debug
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
    _cdc_print 'error' "[$cd_dir] not found." $debug

    return 2
}

##
# Returns "true" if argument is an element in $CDC_IGNORE.
#
# @param string $string
# @return boolean
_cdc_is_excluded_dir() {
    local string="$1"

    ##
    # If $CDC_IGNORE isn't defined or is empty, return "false".
    if ([[ -z $CDC_IGNORE ]] || (( ${#CDC_IGNORE[@]} == 0 ))); then
        return 1
    fi

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
_cdc_repo_list() {
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
                _cdc_print 'warn' \
                    "$dir is in CDC_REPO_DIRS but isn't a directory."
            fi
            continue
        fi

        ##
        # Loop through all subdirectories in the directory.
        for fulldir in "$dir"/*/; do

            ##
            # Remove trailing slash from directory.
            subdir=${fulldir%/}

            ##
            # Remove preceding directories from subdir.
            subdir=${subdir##*/}

            ##
            # If in repos-only mode, and directory isn't a repo, skip it.
            if $CDC_REPOS_ONLY && ! _cdc_is_repo_dir "$fulldir"; then
                continue
            fi

            ##
            # If the directory isn't excluded, add it to the array.
            if ! _cdc_is_excluded_dir "$subdir"; then
                directories+=("$subdir")
            fi
        done
    done

    ##
    # "Return" the array.
    echo "${directories[@]}"
}

##
# Is the directory a repository?
#
# @param string $dir
# @return boolean
_cdc_is_repo_dir() {
    local id
    local dir="$1"

    ##
    # Spin through all known repository markers.
    for marker in ${CDC_REPO_MARKERS[@]}; do

        ##
        # Repo identifier is the passed directory plus the known marker.
        id="$dir/$marker"

        ##
        # If the marker ends with a slash and it's a valid directory, or if it
        # doesn't end with a slash and it's a valid file, then the directory is
        # a repository.
        if [[ $id == */ && -d $id ]] || [[ $id != */ && -f $id ]]; then
            return 0
        fi
    done

    return 1
}

##
# Print a message with colored output.
# TODO This function can definitely be DRY-ed up.
#
# @param string $level
# @param string $message
# @return void
_cdc_print() {
    local level="$1"
    local message="$2"
    local debug="$3"

    ##
    # If we're not debugging, just print the message and return.
    if ! $debug; then
        echo $message
        return
    fi

    ##
    # Case the level of the message and print the appropriate color and message.
    case $level in
        'success')
            printf "${CDC_SUCCESS_COLOR}SUCCESS:${CDC_RESET} $message\n"
            ;;
        'warn')
            printf "${CDC_WARNING_COLOR}WARNING:${CDC_RESET} $message\n" >&2
            ;;
        'error')
            printf "${CDC_ERROR_COLOR}ERROR:${CDC_RESET} $message\n" >&2
            ;;
        ##
        # Hijacking this method to also print our debug booleans.
        'boolean')
            ##
            # If the variable is true, return with success color.
            if $message; then
                printf "${CDC_SUCCESS_COLOR}true$CDC_RESET"
            else
                printf "${CDC_ERROR_COLOR}false$CDC_RESET"
            fi
            ;;
    esac
}
