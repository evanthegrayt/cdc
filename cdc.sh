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
    local which=false
    local cdc_current=false
    local cdc_pop=false
    local cdc_show_history=false
    local cdc_list_ignored=false
    local print_help=false
    local source_config_file=false
    local use_color=${CDC_COLOR:-true}
    local cdc_dirs=($( printf "%s\n" "${CDC_DIRS//:/ }" ))
    local cdc_ignore=($( printf "%s\n" "${CDC_IGNORE//:/ }" ))

    ##
    # The default for auto-push is true. The user can set `CDC_AUTO_PUSH=false`
    # in a startup file, and manually push with `-u`.
    local pushdir=${CDC_AUTO_PUSH:-true}
    local repos_only=${CDC_REPOS_ONLY:-false}

    ##
    # When using getopts in a function, you must declare OPTIND as a local
    # variable, or it will only work the first time you call it.
    local OPTIND

    ##
    # NOTE: Experimental feature.
    # If argument contains a slash, it's assumed to contain subdirectories.
    # This splits them into the directory root and its subdirectories.
    if [[ $1 == */* ]]; then
        local subdir="${1#*/}"
    fi

    ##
    # Case options if present. Suppress errors because we'll supply our own.
    while getopts 'acCdDhilLnprRtuUw' opt 2>/dev/null; do
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
            # -w: Only display the repo's location, like which for executables.
            w) which=true ;;

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
    # Shift out $OPTIND so we can accurately determine how many parameters (not
    # options) were passed. Then, set cd_dir to $1.
    shift $(( OPTIND - 1 ))
    local cd_dir="${1%%/*}"

    ##
    # If colors are enabled, set color values if they're not already set.
    # TODO set a new color instead of unsetting the globals. When the globals
    # are unset, we can't report what they're set to in the debug screen. Pass
    # the variables to the _cdc_print function.
    if [[ $use_color == true ]]; then
        : ${CDC_ERROR_COLOR:='\033[0;31m'}
        : ${CDC_SUCCESS_COLOR:='\033[0;32m'}
        : ${CDC_WARNING_COLOR:='\033[0;33m'}
        CDC_RESET='\033[0m'
    ##
    # If colors are not enabled, unset the color variables.
    else
        unset CDC_ERROR_COLOR CDC_SUCCESS_COLOR CDC_WARNING_COLOR CDC_RESET
    fi

    if [[ $debug == true ]]; then
        echo "========================= ENV ==========================="
        printf "CDC_DIRS         += ${CDC_SUCCESS_COLOR}%s$CDC_RESET\n"\
            "${cdc_dirs[@]}"
        printf "CDC_IGNORE       += ${CDC_ERROR_COLOR}%s$CDC_RESET\n"\
            "${cdc_ignore[@]}"
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

    ##
    # Check for the existence of required variables that should be set in
    # ~/.cdcrc or a startup file. If not found, exit with non-zero return code.
    if (( ${#cdc_dirs[@]} == 0 )); then
        _cdc_print 'error' 'You must set CDC_DIRS in a config file' $debug
        return 1
    fi

    if [[ $print_help == true ]]; then
        printf "${CDC_SUCCESS_COLOR}USAGE: cdc [DIRECTORY]$CDC_RESET"
        printf "${CDC_WARNING_COLOR}\n\n"
        printf 'Flags will always override options set in ~/.cdcrc!'
        printf "${CDC_RESET}\n"
        printf "  ${CDC_WARNING_COLOR}-a${CDC_RESET}"
        echo ' | `cd` to the directory even if it is ignored.'
        printf "  ${CDC_WARNING_COLOR}-c${CDC_RESET}"
        echo ' | Enable colored output'
        printf "  ${CDC_WARNING_COLOR}-C${CDC_RESET}"
        echo ' | Disable colored output'
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
        printf "  ${CDC_WARNING_COLOR}-w${CDC_RESET}"
        echo ' | Print the directory location instead of changing to it.'
        printf "  ${CDC_WARNING_COLOR}-h${CDC_RESET}"
        echo ' | Print this help.'

        return 0
    fi

    if [[ $cdc_list_searched_dirs == true ]]; then
        if [[ $debug == true ]]; then
            _cdc_print 'success' 'Listing searched directories.' $debug
        fi
        printf "%s\n" "${cdc_dirs[@]}" | column
        should_return=true
    fi

    if [[ $cdc_list_dirs == true ]]; then
        if [[ $debug == true ]]; then
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

    if [[ $cdc_toggle == true ]]; then
        ##
        # If the stack doesn't have at least two elements, tell the user.
        if (( ${#CDC_HISTORY[@]} < 2 )); then
            _cdc_print 'error' 'Not enough directories in the stack.' $debug
            (( rc++ ))
        else
            if [[ $debug == true ]]; then
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

    if [[ $cdc_list_ignored == true ]]; then
        ##
        # If the ignore array is empty, return.
        if (( ${#cdc_ignore[@]} == 0 )); then
            if [[ $debug == true ]]; then
                _cdc_print 'warn' 'No directories are being ignored.' $debug
            fi
        else
            if [[ $debug == true ]]; then
                _cdc_print 'success' 'Listing ignored directories.' $debug
            fi

            printf "%s\n" "${cdc_ignore[@]}" | column
        fi

        should_return=true
    fi

    if [[ $cdc_show_history == true ]]; then
        ##
        # If the stack is empty, tell the user.
        if (( ${#CDC_HISTORY[@]} == 0 )); then
            _cdc_print 'error' 'Stack is empty.' $debug
            (( rc++ ))
        else
            if [[ $debug == true ]]; then
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

    if [[ $cdc_current == true ]]; then
        ##
        # If the stack is empty, tell the user.
        if (( ${#CDC_HISTORY[@]} == 0 )); then
            _cdc_print 'error' "Stack is empty." $debug
            (( rc++ ))
        else
            if [[ $debug == true ]]; then
                _cdc_print 'success' \
                    'Changing to current directory in history.' $debug
            fi

            ##
            # cd to the root of the last repository in the history.
            cd ${CDC_HISTORY[-1]}
        fi

        should_return=true
    fi

    if [[ $cdc_pop == true ]]; then
        ##
        # If there aren't enough directories to pop, notify the user.
        if (( ${#CDC_HISTORY[@]} == 0 )); then
            _cdc_print 'error' 'Stack is empty.' $debug
            (( rc++ ))
        elif (( ${#CDC_HISTORY[@]} == 1 )); then
            _cdc_print 'error' 'At beginning of stack.' $debug
            (( rc++ ))
        else
            if [[ $debug == true ]]; then
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
    if [[ $should_return == true ]]; then
        return $rc
    fi

    ##
    # Print usage and exit if the wrong number of arguments are passed.
    if (( $# != 1 )); then
        _cdc_print 'error' 'USAGE: cdc [DIRECTORY]' $debug
        _cdc_print 'error' '  Use `-h` for more help' $debug
        return 1
    fi

    ##
    # Loop through every element in $cdc_dirs.
    for dir in ${cdc_dirs[@]}; do

        ##
        # If a directory is in the $cdc_dirs array, but the directory doesn't
        # exist, print a message to stderr and move on to the next directory in
        # the array.
        if ! [[ -d $dir ]]; then
            if [[ $debug == true ]]; then
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
        elif [[ $allow_ignored == false ]] && _cdc_is_excluded_dir "$cd_dir"; then
            if [[ $debug == true ]]; then
                _cdc_print 'warn' 'Match was found but it is ignored.' $debug
            fi
            continue

        ##
        # If the directory exists, but we're in repos-only mode and the
        # directory isn't a repo, skip it.
        elif [[ $repos_only == true ]] && ! _cdc_is_repo_dir "$dir/$cd_dir"; then
            if [[ $debug == true ]]; then
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
        if [[ $pushdir == true ]]; then
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
                if [[ $debug == true ]]; then
                    _cdc_print 'warn' "$subdir does not exist in $cd_dir." \
                        $debug
                fi
            fi
        fi

        ##
        # Finally, cd to the path, or display it if $which is true.
        if [[ $which == true ]]; then
            echo $wdir
        else
            cd "$wdir"
        fi

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
# Is the argument an element in $CDC_IGNORE?
#
# @param string $string
# @return boolean
_cdc_is_excluded_dir() {
    local element
    local string="$1"
    local cdc_ignore=($( printf "%s\n" "${CDC_IGNORE//:/ }" ))

    ##
    # If $cdc_ignore isn't defined or is empty, return "false".
    if [[ -z $cdc_ignore ]] || (( ${#cdc_ignore[@]} == 0 )); then
        return 1
    fi

    ##
    # Loop through each element of $CDC_IGNORE array.
    for element in "${cdc_ignore[@]}"; do

        ##
        # If the element matches the passed string, return "true" to indicate
        # it's excluded.
        if [[ ${element/\//} == ${string/\//} ]]; then
            return 0
        fi
    done

    ##
    # If nothing matched, return "false".
    return 1
}

##
# Lists repositories found in $cdc_dirs that aren't excluded.
#
# @param string $string
# @return array
_cdc_repo_list() {
    local dir
    local subdir
    local fulldir
    local directories=()
    local debug=${1:-false}
    local cdc_dirs=($( printf "%s\n" "${CDC_DIRS//:/ }" ))

    ##
    # Loop through all elements of $cdc_dirs array.
    for dir in "${cdc_dirs[@]}"; do

        ##
        # If the element isn't a directory that exists, move on.
        if ! [[ -d $dir ]]; then
            if [[ $debug == true ]]; then
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
            if [[ $CDC_REPOS_ONLY == true ]] && ! _cdc_is_repo_dir "$fulldir"; then
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
    local marker
    local dir="$1"
    local repo_markers

    if [[ -n $CDC_REPO_MARKERS ]]; then
        repo_markers=($( printf "%s\n" "${CDC_REPO_MARKERS//:/ }" ))
    else
        repo_markers=(.git/ .git Rakefile Makefile .hg/ .bzr/ .svn/)
    fi


    ##
    # Spin through all known repository markers.
    for marker in ${repo_markers[@]}; do

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
    if [[ $debug == false ]]; then
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
        # Hijacking this function to also print our debug booleans.
        'boolean')
            ##
            # If the variable is true, return with success color.
            if [[ $message == true ]]; then
                printf "${CDC_SUCCESS_COLOR}true$CDC_RESET"
            else
                printf "${CDC_ERROR_COLOR}false$CDC_RESET"
            fi
            ;;
    esac
}

##
# Source the user's config file.
if [[ -f $HOME/.cdcrc ]]; then
    _cdc_print 'warn' "Using ~/.cdcrc is deprecated and will be removed " \
        "in a future version.\nPlease set values in a config file instead."
    source $HOME/.cdcrc
fi

##
# Set the array that will remember the history. Needs to persist.
CDC_HISTORY=()
