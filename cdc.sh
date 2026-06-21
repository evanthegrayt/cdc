##
# The public function that the user calls from the command line.
# Helper functions are namespaced with `_cdc_` because this file is sourced into
# interactive shells.
#
# @param string $cd_dir
# @return void
cdc() {
    ##
    # Set local vars to avoid environment pollution.
    local wdir
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
    local cdc_parent_dirs=false
    local print_help=false
    local terminal_action_count=0
    local has_directory_modifier=false
    local use_color=${CDC_COLOR:-true}
    local CDC_ERROR_COLOR="$CDC_ERROR_COLOR"
    local CDC_SUCCESS_COLOR="$CDC_SUCCESS_COLOR"
    local CDC_WARNING_COLOR="$CDC_WARNING_COLOR"
    local CDC_RESET="$CDC_RESET"

    ##
    # The default for auto-push is true. The user can set `CDC_AUTO_PUSH=false`
    # in a shell config file, and manually push with `-u`.
    local pushdir=${CDC_AUTO_PUSH:-true}
    local repos_only=${CDC_REPOS_ONLY:-false}
    local opt

    ##
    # When using getopts in a function, you must declare OPTIND as a local
    # variable, or it will only work the first time you call it.
    local OPTIND

    ##
    # Case options if present. Suppress errors because we'll supply our own.
    while getopts 'acCdDhilLnPprRtuUw' opt 2>/dev/null; do
        case $opt in

            ##
            # -a: Allow cd-ing to ignored directories.
            a)
                allow_ignored=true
                has_directory_modifier=true
                ;;

            ##
            # -c: Enable color.
            c) use_color=true ;;

            ##
            # -C: Disable color.
            C) use_color=false ;;

            ##
            # -n: cd to the root of the current repository in the stack.
            n)
                cdc_current=true
                (( terminal_action_count += 1 ))
                ;;

            ##
            # -l: List the directories that are cdc-able.
            l)
                cdc_list_dirs=true
                (( terminal_action_count += 1 ))
                ;;

            ##
            # -i: List the directories that are ignored.
            i)
                cdc_list_ignored=true
                (( terminal_action_count += 1 ))
                ;;

            ##
            # -L: List the directories that are searched.
            L)
                cdc_list_searched_dirs=true
                (( terminal_action_count += 1 ))
                ;;

            ##
            # -t: cd to the last repo, but don't add it to the stack.
            t)
                cdc_toggle=true
                (( terminal_action_count += 1 ))
                ;;

            ##
            # -d: List cdc history.
            d)
                cdc_show_history=true
                (( terminal_action_count += 1 ))
                ;;

            ##
            # -p: cd to the last element in the stack and pop it from the array.
            p)
                cdc_pop=true
                (( terminal_action_count += 1 ))
                ;;

            ##
            # -P: cd to a configured parent directory.
            P)
                cdc_parent_dirs=true
                has_directory_modifier=true
                ;;

            ##
            # -r: Force cdc to only cd to repositories.
            r)
                repos_only=true
                has_directory_modifier=true
                ;;

            ##
            # -R: Force cdc to NOT only cd to repositories.
            R)
                repos_only=false
                has_directory_modifier=true
                ;;

            ##
            # -u: Push the directory onto the history stack.
            u)
                pushdir=true
                has_directory_modifier=true
                ;;

            ##
            # -U: Do not push the directory onto the history stack.
            U)
                pushdir=false
                has_directory_modifier=true
                ;;

            ##
            # -D: Debug
            D) debug=true ;;

            ##
            # -w: Only display the repo's location, like which for executables.
            w)
                which=true
                has_directory_modifier=true
                ;;

            ##
            # -h: Print the help.
            h)
                print_help=true
                (( terminal_action_count += 1 ))
                ;;

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
    local subdir

    ##
    # If argument contains a slash, it's assumed to contain subdirectories.
    # This splits them into the directory root and its subdirectories.
    if [[ $1 == */* ]]; then
        subdir="${1#*/}"
    fi

    ##
    # If colors are enabled, set color values for this cdc call. These are
    # local to avoid leaving default color variables in the user's shell.
    if [[ $use_color == true ]]; then
        : ${CDC_ERROR_COLOR:='\033[0;31m'}
        : ${CDC_SUCCESS_COLOR:='\033[0;32m'}
        : ${CDC_WARNING_COLOR:='\033[0;33m'}
        CDC_RESET='\033[0m'
    else
        unset CDC_ERROR_COLOR CDC_SUCCESS_COLOR CDC_WARNING_COLOR CDC_RESET
    fi

    if [[ $debug == true ]]; then
        _cdc_print_debug_env
    fi

    if (( terminal_action_count > 1 )); then
        _cdc_print 'error' 'Use only one standalone option at a time.' $debug
        return 1
    fi

    if (( terminal_action_count == 1 )) && [[ $has_directory_modifier == true ]]; then
        _cdc_print 'error' 'Standalone options cannot be combined with directory options.' $debug
        return 1
    fi

    if (( terminal_action_count == 1 )) && (( $# != 0 )); then
        _cdc_print 'error' 'Standalone options do not accept a directory.' $debug
        _cdc_print 'error' '  Use `-h` for more help' $debug
        return 1
    fi

    if [[ $print_help == true ]]; then
        _cdc_print_help
        return 0
    fi

    ##
    # Check for the required variables that should be exported from a shell
    # config file. If not found, exit with a non-zero return code.
    if [[ -z $CDC_DIRS ]]; then
        _cdc_print 'error' 'You must set CDC_DIRS in a config file' $debug
        return 1
    fi

    if [[ $cdc_list_searched_dirs == true ]]; then
        _cdc_list_searched_dirs "$debug"
        should_return=true
    fi

    if [[ $cdc_list_dirs == true ]]; then
        _cdc_list_available_dirs "$debug"
        should_return=true
    fi

    if [[ $cdc_toggle == true ]]; then
        _cdc_history_toggle "$debug" || (( rc += 1 ))
        should_return=true
    fi

    if [[ $cdc_list_ignored == true ]]; then
        _cdc_list_ignored_dirs "$debug"
        should_return=true
    fi

    if [[ $cdc_show_history == true ]]; then
        _cdc_history_list "$debug" || (( rc += 1 ))
        should_return=true
    fi

    if [[ $cdc_current == true ]]; then
        _cdc_history_current "$debug" || (( rc += 1 ))
        should_return=true
    fi

    if [[ $cdc_pop == true ]]; then
        _cdc_history_pop "$debug" || (( rc += 1 ))
        should_return=true
    fi

    ##
    # If we handled an option-only action above, return.
    if [[ $should_return == true ]]; then
        return $rc
    fi

    ##
    # Print usage and exit if the wrong number of arguments are passed.
    if (( $# != 1 )); then
        _cdc_print 'error' 'USAGE: cdc [OPTION] [DIRECTORY]' $debug
        _cdc_print 'error' '  Use `-h` for more help' $debug
        return 1
    fi

    if [[ $cdc_parent_dirs == true ]]; then
        wdir=$(_cdc_find_parent_dir "$cd_dir" "$allow_ignored" "$debug")
    else
        wdir=$(_cdc_find_dir "$cd_dir" "$allow_ignored" "$repos_only" "$debug")
    fi

    if (( $? == 0 )); then
        ##
        # If pushdir is true and we're changing directories, add the directory
        # to the history stack.
        if [[ $pushdir == true && $which != true ]]; then
            CDC_HISTORY+=("$wdir")
        fi

        wdir=$(_cdc_resolve_subdir "$wdir" "$cd_dir" "$subdir" "$debug")

        ##
        # Finally, cd to the path, or display it if $which is true.
        if [[ $which == true ]]; then
            printf "%s\n" "$wdir"
        else
            cd "$wdir"
        fi

        ##
        # Return a successful code.
        return 0
    fi

    ##
    # If no directory was found, print a message to stderr and return an
    # unsuccessful code.
    _cdc_print 'error' "[$cd_dir] not found." $debug

    return 2
}

##
# Split a colon-delimited string into one path per line.
#
# @param string $string
# @return string
_cdc_parse_colon_string() {
    local string="$1"

    while [[ $string == *:* ]]; do
        printf "%s\n" "${string%%:*}"
        string="${string#*:}"
    done

    [[ -n $string ]] && printf "%s\n" "$string"
}

##
# Print the debug environment report.
#
# @return void
_cdc_print_debug_env() {
    local cdc_dir
    local cdc_ignore

    echo "========================= ENV ==========================="
    while IFS= read -r cdc_dir; do
        printf "CDC_DIRS         += ${CDC_SUCCESS_COLOR}%s$CDC_RESET\n"\
            "$cdc_dir"
    done < <(_cdc_parse_colon_string "$CDC_DIRS")
    while IFS= read -r cdc_ignore; do
        printf "CDC_IGNORE       += ${CDC_ERROR_COLOR}%s$CDC_RESET\n"\
            "$cdc_ignore"
    done < <(_cdc_parse_colon_string "$CDC_IGNORE")
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
}

##
# Print cdc option metadata as tab-delimited records.
#
# Fields:
#   option letter, completion kind, description
#
# @return string
_cdc_option_specs() {
    printf "%s\t%s\t%s\n" 'a' 'directory' 'cd to the directory even if it is ignored'
    printf "%s\t%s\t%s\n" 'c' 'directory' 'Enable colored output'
    printf "%s\t%s\t%s\n" 'C' 'directory' 'Disable colored output'
    printf "%s\t%s\t%s\n" 'l' 'terminal' 'List cdc-able directories'
    printf "%s\t%s\t%s\n" 'L' 'terminal' 'List directories that cdc searches'
    printf "%s\t%s\t%s\n" 'i' 'terminal' 'List ignored directories'
    printf "%s\t%s\t%s\n" 'd' 'terminal' 'List the directories in the stack'
    printf "%s\t%s\t%s\n" 'n' 'terminal' 'cd to the current directory in the stack'
    printf "%s\t%s\t%s\n" 'p' 'terminal' 'cd to the previous directory and pop it from the stack'
    printf "%s\t%s\t%s\n" 'P' 'directory' 'cd to a configured parent directory'
    printf "%s\t%s\t%s\n" 't' 'terminal' 'Toggle between the last two directories in the stack'
    printf "%s\t%s\t%s\n" 'u' 'directory' 'Push the directory onto the stack'
    printf "%s\t%s\t%s\n" 'U' 'directory' 'Do not push the directory onto the stack'
    printf "%s\t%s\t%s\n" 'r' 'directory' 'Only cd to repositories'
    printf "%s\t%s\t%s\n" 'R' 'directory' 'cd to any directory, even if it is not a repository'
    printf "%s\t%s\t%s\n" 'D' 'directory' 'Enable debug mode for unexpected behavior'
    printf "%s\t%s\t%s\n" 'w' 'directory' 'Print the directory location instead of changing to it'
    printf "%s\t%s\t%s\n" 'h' 'terminal' 'Print this help'
}

##
# Print cdc help.
#
# @return void
_cdc_print_help() {
    local opt
    local kind
    local description

    printf "${CDC_SUCCESS_COLOR}USAGE: cdc [OPTION] [DIRECTORY]$CDC_RESET"
    printf "${CDC_WARNING_COLOR}\n\n"
    printf 'Flags will always override options set in shell config files!'
    printf "${CDC_RESET}\n"

    while IFS=$'\t' read -r opt kind description; do
        printf "  ${CDC_WARNING_COLOR}-%s${CDC_RESET}" "$opt"
        printf " | %s\n" "$description"
    done < <(_cdc_option_specs)
}

##
# List the directories cdc searches.
#
# @param boolean $debug
# @return void
_cdc_list_searched_dirs() {
    local debug="$1"

    if [[ $debug == true ]]; then
        _cdc_print 'success' 'Listing searched directories.' $debug
    fi

    _cdc_parse_colon_string "$CDC_DIRS" | column
}

##
# List the directories cdc can change to.
#
# @param boolean $debug
# @return void
_cdc_list_available_dirs() {
    local debug="$1"
    local list

    if [[ $debug == true ]]; then
        _cdc_print 'success' 'Listing available directories.' $debug
    fi

    ##
    # Print the list and pipe to column for nice output. Also pad each element
    # to make them all at least 8 characters long. This is done because column
    # has issues printing strings less than 8 bytes.
    _cdc_repo_list "$debug" | while IFS= read -r list; do
        printf "%-8s\n" "$list"
    done | column
}

##
# List the directories cdc ignores.
#
# @param boolean $debug
# @return void
_cdc_list_ignored_dirs() {
    local debug="$1"
    local cdc_ignore_count=0
    local cdc_ignore

    ##
    # If the ignored-name list is empty, return.
    while IFS= read -r cdc_ignore; do
        (( cdc_ignore_count += 1 ))
    done < <(_cdc_parse_colon_string "$CDC_IGNORE")

    if (( cdc_ignore_count == 0 )); then
        if [[ $debug == true ]]; then
            _cdc_print 'warn' 'No directories are being ignored.' $debug
        fi
    else
        if [[ $debug == true ]]; then
            _cdc_print 'success' 'Listing ignored directories.' $debug
        fi

        _cdc_parse_colon_string "$CDC_IGNORE" | column
    fi
}

##
# Toggle between the last two directories in the history stack.
#
# @param boolean $debug
# @return boolean
_cdc_history_toggle() {
    local debug="$1"
    local cdc_last_element
    local cdc_next_to_last_element
    local cdc_last_index
    local cdc_next_to_last_index

    ##
    # If the stack doesn't have at least two elements, tell the user.
    if (( ${#CDC_HISTORY[@]} < 2 )); then
        _cdc_print 'error' 'Not enough directories in the stack.' $debug
        return 1
    fi

    if [[ $debug == true ]]; then
        _cdc_print 'success' 'Toggling between last two directories.' $debug
    fi

    ##
    # Flip the last two elements of the array.
    cdc_last_index=$(_cdc_array_last_index "${#CDC_HISTORY[@]}")
    cdc_next_to_last_index=$(_cdc_array_next_to_last_index "${#CDC_HISTORY[@]}")
    cdc_last_element=${CDC_HISTORY[$cdc_last_index]}
    cdc_next_to_last_element=${CDC_HISTORY[$cdc_next_to_last_index]}
    CDC_HISTORY=(
        "${CDC_HISTORY[@]:0:$((${#CDC_HISTORY[@]} - 2))}"
        "$cdc_last_element"
        "$cdc_next_to_last_element"
    )

    ##
    # Finally, cd to the last directory in the stack.
    cdc_last_index=$(_cdc_array_last_index "${#CDC_HISTORY[@]}")
    cd "${CDC_HISTORY[$cdc_last_index]}"
    return 0
}

##
# List cdc history.
#
# @param boolean $debug
# @return boolean
_cdc_history_list() {
    local debug="$1"
    local cdc_history

    ##
    # If the stack is empty, tell the user.
    if (( ${#CDC_HISTORY[@]} == 0 )); then
        _cdc_print 'error' 'Stack is empty.' $debug
        return 1
    fi

    if [[ $debug == true ]]; then
        _cdc_print 'success' 'Listing directories in history.' $debug
    fi

    ##
    # Print the array.
    for cdc_history in "${CDC_HISTORY[@]}"; do
        printf "%s " "${cdc_history##*/}"
    done
    echo
}

##
# Change to the current directory in history.
#
# @param boolean $debug
# @return boolean
_cdc_history_current() {
    local debug="$1"
    local cdc_last_index

    ##
    # If the stack is empty, tell the user.
    if (( ${#CDC_HISTORY[@]} == 0 )); then
        _cdc_print 'error' "Stack is empty." $debug
        return 1
    fi

    if [[ $debug == true ]]; then
        _cdc_print 'success' 'Changing to current directory in history.' $debug
    fi

    ##
    # cd to the root of the last repository in the history.
    cdc_last_index=$(_cdc_array_last_index "${#CDC_HISTORY[@]}")
    cd "${CDC_HISTORY[$cdc_last_index]}"
    return 0
}

##
# Change to the previous directory in history.
#
# @param boolean $debug
# @return boolean
_cdc_history_pop() {
    local debug="$1"
    local cdc_last_index

    ##
    # If there aren't enough directories to pop, notify the user.
    if (( ${#CDC_HISTORY[@]} == 0 )); then
        _cdc_print 'error' 'Stack is empty.' $debug
        return 1
    elif (( ${#CDC_HISTORY[@]} == 1 )); then
        _cdc_print 'error' 'At beginning of stack.' $debug
        return 1
    fi

    if [[ $debug == true ]]; then
        _cdc_print 'success' 'Changing to last directory in history.' $debug
    fi

    ##
    # Remove the last element of the array.
    CDC_HISTORY=("${CDC_HISTORY[@]:0:$((${#CDC_HISTORY[@]} - 1))}")

    ##
    # cd to the previous directory in the stack.
    cdc_last_index=$(_cdc_array_last_index "${#CDC_HISTORY[@]}")
    cd "${CDC_HISTORY[$cdc_last_index]}"
    return 0
}

##
# Get the last index for a shell array of the given size.
#
# @param integer $array_size
# @return integer
_cdc_array_last_index() {
    local array_size="$1"

    if [[ -n $ZSH_VERSION ]]; then
        echo "$array_size"
    else
        echo $(( array_size - 1 ))
    fi
}

##
# Get the next-to-last index for a shell array of the given size.
#
# @param integer $array_size
# @return integer
_cdc_array_next_to_last_index() {
    local array_size="$1"

    if [[ -n $ZSH_VERSION ]]; then
        echo $(( array_size - 1 ))
    else
        echo $(( array_size - 2 ))
    fi
}

##
# Find the matching directory for the requested directory name.
#
# @param string $cd_dir
# @param boolean $allow_ignored
# @param boolean $repos_only
# @param boolean $debug
# @return string
_cdc_find_dir() {
    local cd_dir="$1"
    local allow_ignored="$2"
    local repos_only="$3"
    local debug="$4"
    local dir

    ##
    # Loop through every path in the colon-delimited CDC_DIRS value.
    while IFS= read -r dir; do

        ##
        # If a path is in CDC_DIRS but doesn't exist, print a message to stderr
        # and move on to the next configured path.
        if ! [[ -d $dir ]]; then
            if [[ $debug == true ]]; then
                _cdc_print 'warn' \
                    "$dir is in CDC_DIRS but isn't a directory." $debug
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
        # so we print it for the caller.
        echo "$dir/$cd_dir"
        return 0
    done < <(_cdc_parse_colon_string "$CDC_DIRS")

    return 2
}

##
# Find a configured parent directory by its basename.
#
# @param string $cd_dir
# @param boolean $allow_ignored
# @param boolean $debug
# @return string
_cdc_find_parent_dir() {
    local cd_dir="$1"
    local allow_ignored="$2"
    local debug="$3"
    local dir
    local parent_dir

    while IFS= read -r dir; do
        [[ -n $dir ]] || continue

        if ! [[ -d $dir ]]; then
            if [[ $debug == true ]]; then
                _cdc_print 'warn' \
                    "$dir is in CDC_DIRS but isn't a directory." $debug
            fi
            continue
        fi

        parent_dir=${dir%/}
        parent_dir=${parent_dir##*/}

        if [[ $parent_dir != "$cd_dir" ]]; then
            continue
        elif [[ $allow_ignored == false ]] && _cdc_is_excluded_dir "$parent_dir"; then
            if [[ $debug == true ]]; then
                _cdc_print 'warn' 'Match was found but it is ignored.' $debug
            fi
            continue
        fi

        echo "$dir"
        return 0
    done < <(_cdc_parse_colon_string "$CDC_DIRS")

    return 2
}

##
# Append a requested subdirectory if it exists.
#
# @param string $wdir
# @param string $cd_dir
# @param string $subdir
# @param boolean $debug
# @return string
_cdc_resolve_subdir() {
    local wdir="$1"
    local cd_dir="$2"
    local subdir="$3"
    local debug="$4"

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
                _cdc_print 'warn' "$subdir does not exist in $cd_dir." $debug
            fi
        fi
    fi

    echo "$wdir"
}

##
# Is the argument an element in $CDC_IGNORE?
#
# @param string $string
# @return boolean
_cdc_is_excluded_dir() {
    local element
    local string="$1"

    ##
    # If CDC_IGNORE isn't defined or is empty, return "false".
    if [[ -z $CDC_IGNORE ]]; then
        return 1
    fi

    ##
    # Loop through each ignored name in the colon-delimited CDC_IGNORE value.
    while IFS= read -r element; do

        ##
        # If the element matches the passed string, return "true" to indicate
        # it's excluded.
        if [[ ${element/\//} == ${string/\//} ]]; then
            return 0
        fi
    done < <(_cdc_parse_colon_string "$CDC_IGNORE")

    ##
    # If nothing matched, return "false".
    return 1
}

##
# Lists directories found in CDC_DIRS that aren't excluded.
#
# @param boolean $debug
# @return string
_cdc_repo_list() {
    local dir
    local subdir
    local fulldir
    local directories=()
    local debug=${1:-false}

    ##
    # Loop through every path in the colon-delimited CDC_DIRS value.
    while IFS= read -r dir; do

        ##
        # If the element isn't a directory that exists, move on.
        if ! [[ -d $dir ]]; then
            if [[ $debug == true ]]; then
                _cdc_print 'warn' \
                    "$dir is in CDC_DIRS but isn't a directory."
            fi
            continue
        fi

        ##
        # Loop through all subdirectories in the directory.
        for fulldir in "$dir"/*/; do
            [[ -d $fulldir ]] || continue

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
    done < <(_cdc_parse_colon_string "$CDC_DIRS")

    ##
    # Print one matching directory name per line.
    printf "%s\n" "${directories[@]}"
}

##
# List command-line flags that match the given completion kind.
#
# @param string $requested_kind
# @return string
_cdc_completion_options_by_kind() {
    local requested_kind="$1"
    local opt
    local kind
    local description
    local options=()

    while IFS=$'\t' read -r opt kind description; do
        [[ $kind == "$requested_kind" ]] || continue
        options+=("-$opt")
    done < <(_cdc_option_specs)

    echo "${options[*]}"
}

##
# List all command-line flags.
#
# @return string
_cdc_completion_all_options() {
    local opt
    local kind
    local description

    while IFS=$'\t' read -r opt kind description; do
        printf -- "-%s\n" "$opt"
    done < <(_cdc_option_specs)
}

##
# List zsh display descriptions for all command-line flags.
#
# @return string
_cdc_completion_option_descriptions() {
    local opt
    local kind
    local description

    while IFS=$'\t' read -r opt kind description; do
        printf -- "-%s  %s\n" "$opt" "$description"
    done < <(_cdc_option_specs)
}

##
# List command-line flags that complete a cdc invocation without a directory.
#
# @return string
_cdc_completion_terminal_options() {
    _cdc_completion_options_by_kind terminal
}

##
# List command-line flags that still allow a directory argument.
#
# @return string
_cdc_completion_directory_options() {
    _cdc_completion_options_by_kind directory
}

##
# Return the completion kind for an option letter.
#
# @param string $option
# @return string
_cdc_completion_option_kind() {
    local option="$1"
    local opt
    local kind
    local description

    while IFS=$'\t' read -r opt kind description; do
        if [[ $opt == "$option" ]]; then
            echo "$kind"
            return 0
        fi
    done < <(_cdc_option_specs)

    return 1
}

##
# Does a set of already-typed arguments include an option-only action?
#
# @param array $@
# @return boolean
_cdc_completion_has_terminal_action() {
    local arg
    local opt
    local opts

    for arg in "$@"; do
        [[ $arg == -- ]] && return 1
        [[ $arg == -* && $arg != "-" ]] || continue

        opts="${arg#-}"
        while [[ -n $opts ]]; do
            opt="${opts%"${opts#?}"}"
            opts="${opts#?}"

            [[ $(_cdc_completion_option_kind "$opt") == terminal ]] && return 0
        done
    done

    return 1
}

##
# Does a set of already-typed arguments include the directory operand?
#
# @param array $@
# @return boolean
_cdc_completion_has_operand() {
    local arg

    for arg in "$@"; do
        [[ $arg == -- ]] && return 1
        [[ $arg == -* && $arg != "-" ]] && continue
        [[ -n $arg ]] && return 0
    done

    return 1
}

##
# Print completion mode booleans after applying already-typed options.
#
# @param array $@
# @return string
_cdc_completion_mode() {
    local arg
    local opt
    local opts
    local allow_ignored=false
    local parent_dirs=false
    local repos_only=${CDC_REPOS_ONLY:-false}

    for arg in "$@"; do
        [[ $arg == -- ]] && break
        [[ $arg == -* && $arg != "-" ]] || continue

        opts="${arg#-}"
        while [[ -n $opts ]]; do
            opt="${opts%"${opts#?}"}"
            opts="${opts#?}"

            case "$opt" in
                a) allow_ignored=true ;;
                P) parent_dirs=true ;;
                r) repos_only=true ;;
                R) repos_only=false ;;
            esac
        done
    done

    echo "$allow_ignored $repos_only $parent_dirs"
}

##
# List top-level cdc directories for completion under the requested mode.
#
# @param boolean $allow_ignored
# @param boolean $repos_only
# @return string
_cdc_completion_repo_list() {
    local allow_ignored="$1"
    local repos_only="$2"
    local dir
    local fulldir
    local subdir

    while IFS= read -r dir; do
        [[ -d $dir ]] || continue

        for fulldir in "$dir"/*/; do
            [[ -d $fulldir ]] || continue

            subdir=${fulldir%/}
            subdir=${subdir##*/}

            if [[ $allow_ignored == false ]] && _cdc_is_excluded_dir "$subdir"; then
                continue
            fi

            if [[ $repos_only == true ]] && ! _cdc_is_repo_dir "$fulldir"; then
                continue
            fi

            echo "$subdir"
        done
    done < <(_cdc_parse_colon_string "$CDC_DIRS")
}

##
# List configured parent directories for completion.
#
# @param boolean $allow_ignored
# @return string
_cdc_completion_parent_list() {
    local allow_ignored="$1"
    local dir
    local parent_dir

    while IFS= read -r dir; do
        [[ -d $dir ]] || continue

        parent_dir=${dir%/}
        parent_dir=${parent_dir##*/}

        if [[ $allow_ignored == false ]] && _cdc_is_excluded_dir "$parent_dir"; then
            continue
        fi

        echo "$parent_dir"
    done < <(_cdc_parse_colon_string "$CDC_DIRS")
}

##
# List subdirectories under a matched cdc root for completion.
#
# @param string $cd_dir
# @param string $wdir
# @param string $partial_subdir
# @return string
_cdc_completion_subdir_list() {
    local cd_dir="$1"
    local wdir="$2"
    local partial_subdir="$3"
    local parent
    local search_dir
    local candidate_prefix
    local fulldir
    local subdir

    if [[ $partial_subdir == */* ]]; then
        parent="${partial_subdir%/*}"
        search_dir="$wdir/$parent"
        candidate_prefix="$cd_dir/$parent/"
    else
        search_dir="$wdir"
        candidate_prefix="$cd_dir/"
    fi

    [[ -d $search_dir ]] || return 0

    for fulldir in "$search_dir"/*/; do
        [[ -d $fulldir ]] || continue

        subdir=${fulldir%/}
        subdir=${subdir##*/}
        echo "$candidate_prefix$subdir"
    done
}

##
# List directory completions for the current word.
#
# @param string $current
# @param boolean $allow_ignored
# @param boolean $repos_only
# @param boolean $parent_dirs
# @return string
_cdc_completion_list() {
    local current="$1"
    local allow_ignored="${2:-false}"
    local repos_only="${3:-${CDC_REPOS_ONLY:-false}}"
    local parent_dirs="${4:-false}"
    local cd_dir
    local subdir
    local wdir

    if [[ $current == */* ]]; then
        cd_dir="${current%%/*}"
        subdir="${current#*/}"

        if [[ $parent_dirs == true ]]; then
            wdir=$(_cdc_find_parent_dir "$cd_dir" "$allow_ignored" false)
        else
            wdir=$(_cdc_find_dir "$cd_dir" "$allow_ignored" "$repos_only" false)
        fi

        (( $? == 0 )) || return 0

        _cdc_completion_subdir_list "$cd_dir" "$wdir" "$subdir"
        return 0
    fi

    if [[ $parent_dirs == true ]]; then
        _cdc_completion_parent_list "$allow_ignored"
        return 0
    fi

    _cdc_completion_repo_list "$allow_ignored" "$repos_only"
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
        local IFS=$'\n'
        repo_markers=($( _cdc_parse_colon_string "$CDC_REPO_MARKERS" ))
    else
        repo_markers=(.git/ .git Rakefile Makefile .hg/ .bzr/ .svn/)
    fi


    ##
    # Spin through all known repository markers.
    for marker in "${repo_markers[@]}"; do

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
# @param boolean $debug
# @return void
_cdc_print() {
    local level="$1"
    local message="$2"
    local debug="$3"

    ##
    # If we're not debugging, just print the message and return.
    if [[ $debug == false ]]; then
        printf "%s\n" "$message"
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
##
# Set the array that will remember the history. Needs to persist.
CDC_HISTORY=()
