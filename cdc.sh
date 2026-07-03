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
    local cdc_current_root
    local rc=0
    local cdc_list_dirs=false
    local cdc_list_searched_dirs=false
    local cdc_toggle=false
    local verbose=false
    local should_return=false
    local allow_ignored=false
    local which=false
    local cdc_current=false
    local cdc_pop=false
    local cdc_show_history=false
    local cdc_delete_history=false
    local cdc_clear_history=false
    local cdc_list_ignored=false
    local cdc_parent_dirs=false
    local print_help=false
    local terminal_action_count=0
    local has_directory_modifier=false
    local allow_hidden=${CDC_ALLOW_HIDDEN:-false}
    local pushdir_option_set=false
    local use_color=${CDC_COLOR:-true}
    local error_color=${CDC_ERROR_COLOR:-'\033[0;31m'}
    local success_color=${CDC_SUCCESS_COLOR:-'\033[0;32m'}
    local warning_color=${CDC_WARNING_COLOR:-'\033[0;33m'}
    local reset_color='\033[0m'

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
    # Parse short options. getopts errors are suppressed so unsupported flags
    # can use cdc's own error text instead of shell-generated messages.
    while getopts 'acCdDhiHlLnPprRtuUvwxX' opt 2>/dev/null; do
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
            # -H: Include hidden directories in lookup, listing, and completion.
            H)
                allow_hidden=true
                has_directory_modifier=true
                ;;

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
            # -x: Delete matching directories from the history stack.
            x)
                cdc_delete_history=true
                (( terminal_action_count += 1 ))
                ;;

            ##
            # -X: Clear the history stack.
            X)
                cdc_clear_history=true
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
                pushdir_option_set=true
                has_directory_modifier=true
                ;;

            ##
            # -U: Do not push the directory onto the history stack.
            U)
                pushdir=false
                pushdir_option_set=true
                has_directory_modifier=true
                ;;

            ##
            # -v: Verbose
            # -D: Backward-compatible alias for the old flag.
            D|v) verbose=true ;;

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
                _cdc_print 'error' 'Invalid option.' $verbose
                return 1
                ;;
        esac
    done

    ##
    # Shift out parsed options so $# and $1 describe only the directory operand.
    # cd_dir is the first path segment; subdir keeps the rest for later.
    shift $(( OPTIND - 1 ))
    local cd_dir="${1%%/*}"
    local subdir

    ##
    # If the operand contains a slash, treat everything after the first slash as
    # a subdirectory path under the matched cdc root.
    if [[ $1 == */* ]]; then
        subdir="${1#*/}"
    fi

    ##
    if [[ $verbose == true ]]; then
        _cdc_print_verbose_env
    fi

    ##
    # Standalone actions (-l, -d, -p, etc.) do not accept directory operands or
    # directory modifiers because they complete the whole command by themselves.
    if (( terminal_action_count > 1 )); then
        _cdc_print 'error' 'Use only one standalone option at a time.' $verbose
        return 1
    fi

    if (( terminal_action_count == 1 )) && [[ $has_directory_modifier == true ]]; then
        _cdc_print 'error' 'Standalone options cannot be combined with directory options.' $verbose
        return 1
    fi

    if [[ $cdc_delete_history == true ]]; then
        if (( $# != 1 )); then
            _cdc_print 'error' 'History delete requires a directory.' $verbose
            _cdc_print 'error' '  Use `-h` for more help' $verbose
            return 1
        fi
    elif (( terminal_action_count == 1 )) && (( $# != 0 )); then
        _cdc_print 'error' 'Standalone options do not accept a directory.' $verbose
        _cdc_print 'error' '  Use `-h` for more help' $verbose
        return 1
    fi

    if [[ $print_help == true ]]; then
        _cdc_print_help
        return 0
    fi

    ##
    # Check for the required variables that should be exported from a shell
    # config file. If not found, exit with a non-zero return code.
    if [[ -z $CDC_DIRS && -z $CDC_EXPLICIT_DIRS ]]; then
        _cdc_print 'error' \
            'You must set CDC_DIRS or CDC_EXPLICIT_DIRS in a config file' \
            $verbose
        return 1
    fi

    ##
    # Execute the selected option-only action. rc preserves failure from helpers
    # that report their own errors, such as empty history operations.
    if [[ $cdc_list_searched_dirs == true ]]; then
        _cdc_list_searched_dirs "$verbose"
        should_return=true
    fi

    if [[ $cdc_list_dirs == true ]]; then
        _cdc_list_available_dirs "$verbose" "$allow_hidden"
        should_return=true
    fi

    if [[ $cdc_toggle == true ]]; then
        _cdc_history_toggle "$verbose" || (( rc += 1 ))
        should_return=true
    fi

    if [[ $cdc_list_ignored == true ]]; then
        _cdc_list_ignored_dirs "$verbose"
        should_return=true
    fi

    if [[ $cdc_show_history == true ]]; then
        _cdc_history_list "$verbose" || (( rc += 1 ))
        should_return=true
    fi

    if [[ $cdc_current == true ]]; then
        _cdc_history_current "$verbose" || (( rc += 1 ))
        should_return=true
    fi

    if [[ $cdc_pop == true ]]; then
        _cdc_history_pop "$verbose" || (( rc += 1 ))
        should_return=true
    fi

    if [[ $cdc_delete_history == true ]]; then
        _cdc_history_delete "$1" "$verbose" || (( rc += 1 ))
        should_return=true
    fi

    if [[ $cdc_clear_history == true ]]; then
        _cdc_history_clear "$verbose"
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
        _cdc_print 'error' 'USAGE: cdc [OPTION] [DIRECTORY]' $verbose
        _cdc_print 'error' '  Use `-h` for more help' $verbose
        return 1
    fi

    ##
    # `cdc .` is an explicit stack operation for the current directory. In
    # repo-only mode it records the nearest repository root instead.
    if [[ $1 == . ]]; then
        if [[ $repos_only == true ]]; then
            wdir=$(_cdc_find_nearest_repo_dir "$PWD")
        else
            wdir=$PWD
        fi

        if [[ $which == true ]]; then
            printf "%s\n" "$wdir"
        elif [[ $pushdir == true || $pushdir_option_set == false ]]; then
            _cdc_history_push "$wdir"
            _cdc_set_current "$wdir"
        fi

        return 0
    fi

    ##
    # Resolve either a configured parent directory (-P) or a child directory
    # found beneath one of the configured parents.
    if [[ $cdc_parent_dirs == true ]]; then
        wdir=$(_cdc_find_parent_dir "$cd_dir" "$allow_ignored" "$verbose")
    else
        wdir=$(_cdc_find_dir \
            "$cd_dir" "$allow_ignored" "$repos_only" "$verbose" "$allow_hidden")
    fi

    if (( $? == 0 )); then
        cdc_current_root="$wdir"

        ##
        # If pushdir is true and we're changing directories, add the directory
        # to the history stack.
        if [[ $pushdir == true && $which != true ]]; then
            _cdc_history_push "$wdir"
        fi

        ##
        # Append any requested subdirectory after the base match is known. This
        # preserves the long-standing behavior where a missing subdirectory
        # warns in verbose mode but still resolves to the base directory.
        wdir=$(_cdc_resolve_subdir \
            "$wdir" "$cd_dir" "$subdir" "$verbose" "$allow_hidden")

        ##
        # Finally, cd to the path, or display it if $which is true.
        if [[ $which == true ]]; then
            printf "%s\n" "$wdir"
        else
            cd "$wdir" || return 1
            _cdc_set_current "$cdc_current_root"
        fi

        ##
        # Return a successful code.
        return 0
    fi

    ##
    # If no directory was found, print a message to stderr and return an
    # unsuccessful code.
    _cdc_print 'error' "[$cd_dir] not found." $verbose

    return 2
}

##
# Store the last successful cdc target root for use in later shell commands.
#
# @param string $current_dir
# @return void
_cdc_set_current() {
    export CDC_CURRENT="$1"
}

##
# Push a directory onto the history stack.
#
# When CDC_IGNORE_DUPS is true, remove any existing matching entry first so the
# current directory remains at the end of the stack without duplicates.
#
# @param string $dir
# @return void
_cdc_history_push() {
    local dir="$1"
    local cdc_history
    local -a cdc_new_history=()

    if [[ ${CDC_IGNORE_DUPS:-false} != true ]]; then
        CDC_HISTORY+=("$dir")
        return
    fi

    for cdc_history in "${CDC_HISTORY[@]}"; do
        [[ $cdc_history == "$dir" ]] && continue
        cdc_new_history+=("$cdc_history")
    done

    CDC_HISTORY=("${cdc_new_history[@]}" "$dir")
}

##
# Delete matching directories from the history stack.
#
# The match is intentionally limited to existing history entries, accepting
# either the full stored path or the displayed basename.
#
# @param string $dir
# @param boolean $verbose
# @return boolean
_cdc_history_delete() {
    local dir="$1"
    local verbose="$2"
    local cdc_history
    local cdc_history_basename
    local cdc_deleted=false
    local -a cdc_new_history=()

    if (( ${#CDC_HISTORY[@]} == 0 )); then
        _cdc_print 'error' 'Stack is empty.' $verbose
        return 1
    fi

    for cdc_history in "${CDC_HISTORY[@]}"; do
        cdc_history_basename="${cdc_history##*/}"

        if [[ $cdc_history == "$dir" || $cdc_history_basename == "$dir" ]]; then
            cdc_deleted=true
            continue
        fi

        cdc_new_history+=("$cdc_history")
    done

    if [[ $cdc_deleted != true ]]; then
        _cdc_print 'error' "[$dir] not found in history." $verbose
        return 1
    fi

    if [[ $verbose == true ]]; then
        _cdc_print 'success' 'Deleting directories from history.' $verbose
    fi

    CDC_HISTORY=("${cdc_new_history[@]}")
}

##
# Clear the history stack.
#
# @param boolean $verbose
# @return void
_cdc_history_clear() {
    local verbose="$1"

    if [[ $verbose == true ]]; then
        _cdc_print 'success' 'Clearing history.' $verbose
    fi

    CDC_HISTORY=()
}

##
# Split a colon-delimited string into one path per line.
#
# @param string $string
# @return string
_cdc_parse_colon_string() {
    local string="$1"

    ##
    # Repeatedly peel off the text before the next colon. This preserves spaces
    # inside individual entries because read callers consume one printed line.
    while [[ $string == *:* ]]; do
        printf "%s\n" "${string%%:*}"
        string="${string#*:}"
    done

    ##
    # Print the final element after the last colon, if one exists.
    [[ -n $string ]] && printf "%s\n" "$string"
}

##
# Remove trailing slashes from a directory path, preserving root.
#
# @param string $path
# @return string
_cdc_normalize_dir_path() {
    local path="$1"

    while [[ $path == */ && $path != / ]]; do
        path=${path%/}
    done

    printf "%s\n" "$path"
}

##
# List child directories under a parent path.
#
# @param string $dir
# @param boolean $allow_hidden
# @return string
_cdc_child_dirs() {
    local dir="$1"
    local allow_hidden="${2:-false}"
    local fulldir

    dir=$(_cdc_normalize_dir_path "$dir")

    ##
    # zsh raises an error for non-matching globs by default; bash leaves the
    # pattern untouched. null_glob lets the loops below behave the same in zsh.
    if [[ -n $ZSH_VERSION ]]; then
        setopt local_options null_glob
    fi

    ##
    # Normal globs intentionally do not include hidden entries.
    for fulldir in "$dir"/*/; do
        [[ -d $fulldir ]] || continue
        printf "%s\n" "$fulldir"
    done

    ##
    # Hidden globs are split into .[!.]* and ..?* so . and .. are never returned.
    if [[ $allow_hidden == true ]]; then
        for fulldir in "$dir"/.[!.]*/ "$dir"/..?*/; do
            [[ -d $fulldir ]] || continue
            printf "%s\n" "$fulldir"
        done
    fi
}

##
# Print the verbose environment report.
#
# @return void
_cdc_print_verbose_env() {
    local cdc_dir
    local cdc_ignore
    local success_prefix
    local warning_prefix
    local error_prefix
    local reset_prefix

    if [[ $use_color == true ]]; then
        success_prefix="$success_color"
        warning_prefix="$warning_color"
        error_prefix="$error_color"
        reset_prefix="$reset_color"
    fi

    echo "========================= ENV ==========================="
    while IFS= read -r cdc_dir; do
        printf "CDC_DIRS          += %b%s%b\n" \
            "$success_prefix" "$cdc_dir" "$reset_prefix"
    done < <(_cdc_parse_colon_string "$CDC_DIRS")
    while IFS= read -r cdc_dir; do
        printf "CDC_EXPLICIT_DIRS += %b%s%b\n" \
            "$success_prefix" "$cdc_dir" "$reset_prefix"
    done < <(_cdc_parse_colon_string "$CDC_EXPLICIT_DIRS")
    while IFS= read -r cdc_ignore; do
        printf "CDC_IGNORE        += %b%s%b\n" \
            "$error_prefix" "$cdc_ignore" "$reset_prefix"
    done < <(_cdc_parse_colon_string "$CDC_IGNORE")
    echo
    printf "CDC_AUTO_PUSH     = %s\n" \
        $( _cdc_print 'boolean' $CDC_AUTO_PUSH )
    printf "CDC_IGNORE_DUPS   = %s\n" \
        $( _cdc_print 'boolean' $CDC_IGNORE_DUPS )
    printf "CDC_REPOS_ONLY    = %s\n" \
        $( _cdc_print 'boolean' $CDC_REPOS_ONLY )
    printf "CDC_ALLOW_HIDDEN  = %s\n" \
        $( _cdc_print 'boolean' $CDC_ALLOW_HIDDEN )
    printf "CDC_COLOR         = %s\n" \
        $( _cdc_print 'boolean' $CDC_COLOR )
    echo
    printf "CDC_SUCCESS_COLOR = %b%s%b\n" \
        "$success_prefix" "$success_color" "$reset_prefix"
    printf "CDC_WARNING_COLOR = %b%s%b\n" \
        "$warning_prefix" "$warning_color" "$reset_prefix"
    printf "CDC_ERROR_COLOR   = %b%s%b\n" \
        "$error_prefix" "$error_color" "$reset_prefix"
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
    printf "%s\t%s\t%s\n" 'H' 'directory' 'Include hidden directories in lookup, listing, and completion'
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
    printf "%s\t%s\t%s\n" 'x' 'history' 'Delete matching directories from the stack'
    printf "%s\t%s\t%s\n" 'X' 'terminal' 'Clear the history stack'
    printf "%s\t%s\t%s\n" 'r' 'directory' 'Only cd to repositories'
    printf "%s\t%s\t%s\n" 'R' 'directory' 'cd to any directory, even if it is not a repository'
    printf "%s\t%s\t%s\n" 'v' 'directory' 'Enable verbose output'
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
    local success_prefix
    local warning_prefix
    local reset_prefix

    if [[ $use_color == true ]]; then
        success_prefix="$success_color"
        warning_prefix="$warning_color"
        reset_prefix="$reset_color"
    fi

    printf "%bUSAGE: cdc [OPTION] [DIRECTORY]%b" \
        "$success_prefix" "$reset_prefix"
    printf "%b\n\n" "$warning_prefix"
    printf 'Flags will always override options set in shell config files!'
    printf "%b\n" "$reset_prefix"

    while IFS=$'\t' read -r opt kind description; do
        printf "  %b-%s%b" "$warning_prefix" "$opt" "$reset_prefix"
        printf " | %s\n" "$description"
    done < <(_cdc_option_specs)
}

##
# List the directories cdc searches.
#
# @param boolean $verbose
# @return void
_cdc_list_searched_dirs() {
    local verbose="$1"

    if [[ $verbose == true ]]; then
        _cdc_print 'success' 'Listing searched directories.' $verbose
    fi

    _cdc_parse_colon_string "$CDC_DIRS" | column
}

##
# List the directories cdc can change to.
#
# @param boolean $verbose
# @param boolean $allow_hidden
# @return void
_cdc_list_available_dirs() {
    local verbose="$1"
    local allow_hidden="${2:-${CDC_ALLOW_HIDDEN:-false}}"
    local list

    if [[ $verbose == true ]]; then
        _cdc_print 'success' 'Listing available directories.' $verbose
    fi

    ##
    # Print the list and pipe to column for nice output. Also pad each element
    # to make them all at least 8 characters long. This is done because column
    # has issues printing strings less than 8 bytes.
    _cdc_repo_list "$verbose" "$allow_hidden" | while IFS= read -r list; do
        printf "%-8s\n" "$list"
    done | column
}

##
# List the directories cdc ignores.
#
# @param boolean $verbose
# @return void
_cdc_list_ignored_dirs() {
    local verbose="$1"
    local cdc_ignore_count=0
    local cdc_ignore

    ##
    # If the ignored-name list is empty, return.
    while IFS= read -r cdc_ignore; do
        (( cdc_ignore_count += 1 ))
    done < <(_cdc_parse_colon_string "$CDC_IGNORE")

    if (( cdc_ignore_count == 0 )); then
        if [[ $verbose == true ]]; then
            _cdc_print 'warn' 'No directories are being ignored.' $verbose
        fi
    else
        if [[ $verbose == true ]]; then
            _cdc_print 'success' 'Listing ignored directories.' $verbose
        fi

        _cdc_parse_colon_string "$CDC_IGNORE" | column
    fi
}

##
# Toggle between the last two directories in the history stack.
#
# @param boolean $verbose
# @return boolean
_cdc_history_toggle() {
    local verbose="$1"
    local cdc_last_element
    local cdc_next_to_last_element
    local cdc_last_index
    local cdc_next_to_last_index

    ##
    # If the stack doesn't have at least two elements, tell the user.
    if (( ${#CDC_HISTORY[@]} < 2 )); then
        _cdc_print 'error' 'Not enough directories in the stack.' $verbose
        return 1
    fi

    if [[ $verbose == true ]]; then
        _cdc_print 'success' 'Toggling between last two directories.' $verbose
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
    cd "${CDC_HISTORY[$cdc_last_index]}" || return 1
    _cdc_set_current "${CDC_HISTORY[$cdc_last_index]}"
    return 0
}

##
# List cdc history.
#
# @param boolean $verbose
# @return boolean
_cdc_history_list() {
    local verbose="$1"
    local cdc_history

    ##
    # If the stack is empty, tell the user.
    if (( ${#CDC_HISTORY[@]} == 0 )); then
        _cdc_print 'error' 'Stack is empty.' $verbose
        return 1
    fi

    if [[ $verbose == true ]]; then
        _cdc_print 'success' 'Listing directories in history.' $verbose
    fi

    ##
    # Print the array.
    for cdc_history in "${CDC_HISTORY[@]}"; do
        if [[ $verbose == true ]]; then
            printf "%s " "$cdc_history"
        else
            printf "%s " "${cdc_history##*/}"
        fi
    done
    echo
}

##
# Change to the current directory in history.
#
# @param boolean $verbose
# @return boolean
_cdc_history_current() {
    local verbose="$1"
    local cdc_last_index

    ##
    # If the stack is empty, tell the user.
    if (( ${#CDC_HISTORY[@]} == 0 )); then
        _cdc_print 'error' "Stack is empty." $verbose
        return 1
    fi

    if [[ $verbose == true ]]; then
        _cdc_print 'success' 'Changing to current directory in history.' $verbose
    fi

    ##
    # cd to the root of the last repository in the history.
    cdc_last_index=$(_cdc_array_last_index "${#CDC_HISTORY[@]}")
    cd "${CDC_HISTORY[$cdc_last_index]}" || return 1
    _cdc_set_current "${CDC_HISTORY[$cdc_last_index]}"
    return 0
}

##
# Change to the previous directory in history.
#
# @param boolean $verbose
# @return boolean
_cdc_history_pop() {
    local verbose="$1"
    local cdc_last_index

    ##
    # If there aren't enough directories to pop, notify the user.
    if (( ${#CDC_HISTORY[@]} == 0 )); then
        _cdc_print 'error' 'Stack is empty.' $verbose
        return 1
    elif (( ${#CDC_HISTORY[@]} == 1 )); then
        _cdc_print 'error' 'At beginning of stack.' $verbose
        return 1
    fi

    if [[ $verbose == true ]]; then
        _cdc_print 'success' 'Changing to last directory in history.' $verbose
    fi

    ##
    # Remove the last element of the array.
    CDC_HISTORY=("${CDC_HISTORY[@]:0:$((${#CDC_HISTORY[@]} - 1))}")

    ##
    # cd to the previous directory in the stack.
    cdc_last_index=$(_cdc_array_last_index "${#CDC_HISTORY[@]}")
    cd "${CDC_HISTORY[$cdc_last_index]}" || return 1
    _cdc_set_current "${CDC_HISTORY[$cdc_last_index]}"
    return 0
}

##
# Find the nearest repository ancestor for the current directory.
#
# @param string $dir
# @return string
_cdc_find_nearest_repo_dir() {
    local dir="$1"

    ##
    # Walk upward from the current directory until a repository marker is found
    # or the filesystem root is reached.
    while [[ -n $dir ]]; do
        if _cdc_is_repo_dir "$dir"; then
            echo "$dir"
            return 0
        fi

        if [[ $dir == / ]]; then
            break
        fi

        dir=${dir%/*}
        [[ -n $dir ]] || dir=/
    done

    echo "$PWD"
}

##
# Get the last index for a shell array of the given size.
#
# @param integer $array_size
# @return integer
_cdc_array_last_index() {
    local array_size="$1"

    ##
    # zsh arrays are 1-indexed; bash arrays are 0-indexed.
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

    ##
    # zsh arrays are 1-indexed; bash arrays are 0-indexed.
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
# @param boolean $verbose
# @param boolean $allow_hidden
# @return string
_cdc_find_dir() {
    local cd_dir="$1"
    local allow_ignored="$2"
    local repos_only="$3"
    local verbose="$4"
    local allow_hidden="${5:-${CDC_ALLOW_HIDDEN:-false}}"
    local dir
    local dir_path

    _cdc_find_explicit_dir "$cd_dir" "$verbose" && return 0

    ##
    # Loop through every path in the colon-delimited CDC_DIRS value.
    while IFS= read -r dir; do

        ##
        # If a path is in CDC_DIRS but doesn't exist, print a message to stderr
        # and move on to the next configured path.
        if ! [[ -d $dir ]]; then
            if [[ $verbose == true ]]; then
                _cdc_print 'warn' \
                    "$dir is in CDC_DIRS but isn't a directory." $verbose
            fi
            continue
        fi
        dir_path=$(_cdc_normalize_dir_path "$dir")

        ##
        # If the element is not a directory, skip it.
        if [[ ! -d $dir_path/$cd_dir ]]; then
            continue

        ##
        # If the directory exists, but is excluded, skip it.
        elif [[ $allow_ignored == false ]] \
            && _cdc_is_excluded_dir "$dir_path/$cd_dir"; then
            if [[ $verbose == true ]]; then
                _cdc_print 'warn' 'Match was found but it is ignored.' $verbose
            fi
            continue

        ##
        # If the directory exists, but is hidden, skip it unless allowed.
        elif [[ $allow_hidden == false ]] && _cdc_is_hidden_dir "$cd_dir"; then
            if [[ $verbose == true ]]; then
                _cdc_print 'warn' \
                    'Match was found but hidden directories are not allowed.' \
                    $verbose
            fi
            continue

        ##
        # If the directory exists, but we're in repos-only mode and the
        # directory isn't a repo, skip it.
        elif [[ $repos_only == true ]] \
            && ! _cdc_is_repo_dir "$dir_path/$cd_dir"; then
            if [[ $verbose == true ]]; then
                _cdc_print 'warn' \
                    'Match was found but it is not a repository.' $verbose
            fi
            continue
        fi

        ##
        # By this point, the match exists and passed ignore/hidden/repo checks,
        # so print the absolute path for the caller.
        echo "$dir_path/$cd_dir"
        return 0
    done < <(_cdc_parse_colon_string "$CDC_DIRS")

    return 2
}

##
# Find a configured explicit directory by its basename.
#
# @param string $cd_dir
# @param boolean $verbose
# @return string
_cdc_find_explicit_dir() {
    local cd_dir="$1"
    local verbose="$2"
    local dir
    local dir_path
    local explicit_dir

    while IFS= read -r dir; do
        [[ -n $dir ]] || continue

        if ! [[ -d $dir ]]; then
            if [[ $verbose == true ]]; then
                _cdc_print 'warn' \
                    "$dir is in CDC_EXPLICIT_DIRS but isn't a directory." \
                    $verbose
            fi
            continue
        fi

        dir_path=$(_cdc_normalize_dir_path "$dir")
        explicit_dir=${dir_path##*/}

        if [[ $explicit_dir == "$cd_dir" ]]; then
            echo "$dir_path"
            return 0
        fi
    done < <(_cdc_parse_colon_string "$CDC_EXPLICIT_DIRS")

    return 2
}

##
# Find a configured parent directory by its basename.
#
# @param string $cd_dir
# @param boolean $allow_ignored
# @param boolean $verbose
# @return string
_cdc_find_parent_dir() {
    local cd_dir="$1"
    local allow_ignored="$2"
    local verbose="$3"
    local dir
    local dir_path
    local parent_dir

    while IFS= read -r dir; do
        [[ -n $dir ]] || continue

        if ! [[ -d $dir ]]; then
            if [[ $verbose == true ]]; then
                _cdc_print 'warn' \
                    "$dir is in CDC_DIRS but isn't a directory." $verbose
            fi
            continue
        fi
        dir_path=$(_cdc_normalize_dir_path "$dir")

        parent_dir=${dir_path##*/}

        ##
        # -P searches configured CDC_DIRS entries by basename. Hidden configured
        # parents are explicit entries and are not gated by CDC_ALLOW_HIDDEN.
        if [[ $parent_dir != "$cd_dir" ]]; then
            continue
        elif [[ $allow_ignored == false ]] && _cdc_is_excluded_dir "$dir_path"; then
            if [[ $verbose == true ]]; then
                _cdc_print 'warn' 'Match was found but it is ignored.' $verbose
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
# @param boolean $verbose
# @param boolean $allow_hidden
# @return string
_cdc_resolve_subdir() {
    local wdir="$1"
    local cd_dir="$2"
    local subdir="$3"
    local verbose="$4"
    local allow_hidden="${5:-${CDC_ALLOW_HIDDEN:-false}}"

    ##
    # If the user passed a subdirectory path, decide whether it can be appended
    # to the already-resolved cdc root.
    if [[ -n $subdir ]]; then

        ##
        # A hidden subdirectory is treated like a missing subdirectory unless
        # hidden directories are explicitly allowed.
        if [[ -d $wdir/$subdir ]] \
            && [[ $allow_hidden == false ]] \
            && _cdc_path_contains_hidden_dir "$subdir"; then
            if [[ $verbose == true ]]; then
                _cdc_print 'warn' \
                    'Match was found but hidden directories are not allowed.' \
                    $verbose
            fi
        ##
        # If it exists as an allowed directory, append it to the path.
        elif [[ -d $wdir/$subdir ]]; then
            wdir+="/$subdir"
        else

            ##
            # If it doesn't exist as a directory, print message to stderr.
            if [[ $verbose == true ]]; then
                _cdc_print 'warn' "$subdir does not exist in $cd_dir." $verbose
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
    local ignored_path
    local ignored_basename
    local string="$1"
    local string_basename
    local string_path

    ##
    # If CDC_IGNORE isn't defined or is empty, return "false".
    if [[ -z $CDC_IGNORE ]]; then
        return 1
    fi

    string_path=$(_cdc_normalize_dir_path "$string")
    string_basename=${string_path##*/}

    ##
    # Loop through each ignored name in the colon-delimited CDC_IGNORE value.
    while IFS= read -r element; do
        [[ -n $element ]] || continue
        ignored_path=$(_cdc_normalize_dir_path "$element")
        ignored_basename=${ignored_path##*/}

        ##
        # Path-like entries only ignore that exact directory, while bare names
        # keep matching any directory with that basename.
        if [[ $ignored_path == */* ]]; then
            if [[ $ignored_path == "$string_path" ]]; then
                return 0
            fi
        elif [[ $ignored_basename == "$string_basename" ]]; then
            return 0
        fi
    done < <(_cdc_parse_colon_string "$CDC_IGNORE")

    ##
    # If nothing matched, return "false".
    return 1
}

##
# Is the argument a hidden directory name?
#
# @param string $string
# @return boolean
_cdc_is_hidden_dir() {
    local string="$1"

    ##
    # A leading dot marks hidden names, but . and .. are shell path syntax, not
    # hidden directories that cdc should gate.
    [[ $string == .* && $string != . && $string != .. ]]
}

##
# Does a relative path contain a hidden directory segment?
#
# @param string $path
# @return boolean
_cdc_path_contains_hidden_dir() {
    local path="$1"
    local segment

    ##
    # Walk each path segment so nested values like foo/.cache/bar are blocked
    # even when the cdc root itself is visible.
    while [[ $path == */* ]]; do
        segment="${path%%/*}"
        path="${path#*/}"

        if _cdc_is_hidden_dir "$segment"; then
            return 0
        fi
    done

    _cdc_is_hidden_dir "$path"
}

##
# Lists directories found in CDC_DIRS that aren't excluded.
#
# @param boolean $verbose
# @param boolean $allow_hidden
# @return string
_cdc_repo_list() {
    local dir
    local subdir
    local fulldir
    local directories=()
    local verbose=${1:-false}
    local allow_hidden="${2:-${CDC_ALLOW_HIDDEN:-false}}"

    while IFS= read -r dir; do
        [[ -n $dir ]] || continue

        if ! [[ -d $dir ]]; then
            if [[ $verbose == true ]]; then
                _cdc_print 'warn' \
                    "$dir is in CDC_EXPLICIT_DIRS but isn't a directory." \
                    $verbose
            fi
            continue
        fi

        dir=$(_cdc_normalize_dir_path "$dir")
        directories+=("${dir##*/}")
    done < <(_cdc_parse_colon_string "$CDC_EXPLICIT_DIRS")

    ##
    # Loop through every path in the colon-delimited CDC_DIRS value.
    while IFS= read -r dir; do

        ##
        # If the element isn't a directory that exists, move on.
        if ! [[ -d $dir ]]; then
            if [[ $verbose == true ]]; then
                _cdc_print 'warn' \
                    "$dir is in CDC_DIRS but isn't a directory."
            fi
            continue
        fi

        ##
        # Loop through all subdirectories in the directory.
        while IFS= read -r fulldir; do
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
            if ! _cdc_is_excluded_dir "$fulldir"; then
                directories+=("$subdir")
            fi
        done < <(_cdc_child_dirs "$dir" "$allow_hidden")
    done < <(_cdc_parse_colon_string "$CDC_DIRS")

    ##
    # Print one matching directory name per line.
    printf "%s\n" "${directories[@]}"
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
# @param boolean $verbose
# @return void
_cdc_print() {
    local level="$1"
    local message="$2"
    local verbose="$3"
    local success_prefix
    local warning_prefix
    local error_prefix
    local reset_prefix

    if [[ $use_color == true ]]; then
        success_prefix="$success_color"
        warning_prefix="$warning_color"
        error_prefix="$error_color"
        reset_prefix="$reset_color"
    fi

    ##
    # If verbose output is disabled, just print the message and return.
    if [[ $verbose == false ]]; then
        printf "%s\n" "$message"
        return
    fi

    ##
    # Case the level of the message and print the appropriate color and message.
    case $level in
        'success')
            printf "%bSUCCESS:%b %s\n" \
                "$success_prefix" "$reset_prefix" "$message"
            ;;
        'warn')
            printf "%bWARNING:%b %s\n" \
                "$warning_prefix" "$reset_prefix" "$message" >&2
            ;;
        'error')
            printf "%bERROR:%b %s\n" \
                "$error_prefix" "$reset_prefix" "$message" >&2
            ;;
        ##
        # Hijacking this function to also print our verbose booleans.
        'boolean')
            ##
            # If the variable is true, return with success color.
            if [[ $message == true ]]; then
                printf "%btrue%b" "$success_prefix" "$reset_prefix"
            else
                printf "%bfalse%b" "$error_prefix" "$reset_prefix"
            fi
            ;;
    esac
}

##
##
# Set the array that will remember the history. Needs to persist.
CDC_HISTORY=()
