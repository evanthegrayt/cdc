##
# Shared completion helpers for bash and zsh plugin wrappers.
#
# Source cdc.sh before this file.

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

    ##
    # Option metadata lives in cdc.sh so help text and shell completion cannot
    # drift apart.
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
        ##
        # `--` ends option parsing. Anything after it is an operand, so there is
        # no terminal action for completion to honor.
        [[ $arg == -- ]] && return 1
        [[ $arg == -* && $arg != "-" ]] || continue

        ##
        # Combined short options like -Rw are expanded one character at a time.
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
        ##
        # Once options are terminated, completion should not treat later values
        # as flags.
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
    local allow_hidden=${CDC_ALLOW_HIDDEN:-false}
    local parent_dirs=false
    local repos_only=${CDC_REPOS_ONLY:-false}

    ##
    # Start from environment defaults, then apply already-typed directory
    # modifiers in command-line order so flags override shell config.
    for arg in "$@"; do
        [[ $arg == -- ]] && break
        [[ $arg == -* && $arg != "-" ]] || continue

        opts="${arg#-}"
        while [[ -n $opts ]]; do
            opt="${opts%"${opts#?}"}"
            opts="${opts#?}"

            case "$opt" in
                a) allow_ignored=true ;;
                H) allow_hidden=true ;;
                P) parent_dirs=true ;;
                r) repos_only=true ;;
                R) repos_only=false ;;
            esac
        done
    done

    echo "$allow_ignored $repos_only $parent_dirs $allow_hidden"
}

##
# List top-level cdc directories for completion under the requested mode.
#
# @param boolean $allow_ignored
# @param boolean $repos_only
# @param boolean $allow_hidden
# @return string
_cdc_completion_repo_list() {
    local allow_ignored="$1"
    local repos_only="$2"
    local allow_hidden="${3:-${CDC_ALLOW_HIDDEN:-false}}"
    local dir
    local fulldir
    local subdir

    while IFS= read -r dir; do
        [[ -d $dir ]] || continue

        ##
        # Use the same child-directory helper as `cdc -l` so hidden directory
        # behavior is identical between listing and completion.
        while IFS= read -r fulldir; do
            subdir=${fulldir%/}
            subdir=${subdir##*/}

            if [[ $allow_ignored == false ]] && _cdc_is_excluded_dir "$subdir"; then
                continue
            fi

            if [[ $repos_only == true ]] && ! _cdc_is_repo_dir "$fulldir"; then
                continue
            fi

            echo "$subdir"
        done < <(_cdc_child_dirs "$dir" "$allow_hidden")
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

        ##
        # -P completes the configured parents themselves, not their children.
        # Hidden configured parents are explicit CDC_DIRS entries and remain
        # visible; CDC_IGNORE still applies by basename.
        parent_dir=${dir%/}
        parent_dir=${parent_dir##*/}

        if [[ $allow_ignored == false ]] && _cdc_is_excluded_dir "$parent_dir"; then
            continue
        fi

        echo "$parent_dir"
    done < <(_cdc_parse_colon_string "$CDC_DIRS")
}

##
# Downcase a value for completion-only matching.
#
# @param string $value
# @return string
_cdc_completion_downcase() {
    printf "%s" "$1" | tr '[:upper:]' '[:lower:]'
}

##
# Return success when a completion candidate matches the current word, ignoring case.
#
# @param string $current
# @param string $candidate
# @return boolean
_cdc_completion_matches_current() {
    local current
    local candidate

    current=$(_cdc_completion_downcase "$1")
    candidate=$(_cdc_completion_downcase "$2")

    [[ $candidate == "$current"* ]]
}

##
# Return success when a completion candidate equals the current word, ignoring case.
#
# @param string $current
# @param string $candidate
# @return boolean
_cdc_completion_matches_exact() {
    local current
    local candidate

    current=$(_cdc_completion_downcase "$1")
    candidate=$(_cdc_completion_downcase "$2")

    [[ $candidate == "$current" ]]
}

##
# Filter completion candidates against the current word, ignoring case.
#
# @param string $current
# @return string
_cdc_completion_filter() {
    local current="$1"
    local candidate

    while IFS= read -r candidate; do
        ##
        # Shell completion matching is case-insensitive even before compadd gets
        # the zsh matcher, so bash and zsh share the same candidate list.
        if _cdc_completion_matches_current "$current" "$candidate"; then
            echo "$candidate"
        fi
    done
}

##
# Print the first candidate that exactly matches the current word, ignoring case.
#
# @param string $current
# @return string
_cdc_completion_select_match() {
    local current="$1"
    local candidate

    while IFS= read -r candidate; do
        ##
        # When completing subdirectories, first recover the canonical casing of
        # the selected cdc root.
        if _cdc_completion_matches_exact "$current" "$candidate"; then
            echo "$candidate"
            return 0
        fi
    done

    return 2
}

##
# Resolve a typed subdirectory path to its on-disk casing for completion.
#
# @param string $base_dir
# @param string $subdir_path
# @param boolean $allow_hidden
# @return string
_cdc_completion_resolve_case_path() {
    local base_dir="$1"
    local subdir_path="$2"
    local allow_hidden="${3:-${CDC_ALLOW_HIDDEN:-false}}"
    local resolved="$base_dir"
    local remaining="$subdir_path"
    local segment
    local fulldir
    local fulldir_name
    local candidate

    ##
    # Resolve one path segment at a time so `repo/src` can be matched
    # case-insensitively against the real on-disk names.
    while [[ -n $remaining ]]; do
        if [[ $remaining == */* ]]; then
            segment="${remaining%%/*}"
            remaining="${remaining#*/}"
        else
            segment="$remaining"
            remaining=""
        fi

        [[ -n $segment ]] || continue

        ##
        # Search only directories that are allowed in the current completion
        # mode, including hidden directories only for -H or CDC_ALLOW_HIDDEN.
        candidate=""
        while IFS= read -r fulldir; do
            fulldir_name=${fulldir%/}
            fulldir_name=${fulldir_name##*/}

            if _cdc_completion_matches_exact "$segment" "$fulldir_name"; then
                candidate="${fulldir%/}"
                break
            fi
        done < <(_cdc_child_dirs "$resolved" "$allow_hidden")

        [[ -n $candidate ]] || return 2
        resolved="$candidate"
    done

    echo "$resolved"
}

##
# List subdirectories under a matched cdc root for completion.
#
# @param string $current
# @param string $cd_dir
# @param string $wdir
# @param string $partial_subdir
# @param boolean $allow_hidden
# @return string
_cdc_completion_subdir_list() {
    local current="$1"
    local cd_dir="$2"
    local wdir="$3"
    local partial_subdir="$4"
    local allow_hidden="${5:-${CDC_ALLOW_HIDDEN:-false}}"
    local root_dir
    local parent
    local search_dir
    local candidate_prefix
    local fulldir
    local subdir
    local candidate

    if [[ $partial_subdir == */* ]]; then
        ##
        # For nested completion, resolve the already-typed parent path to its
        # on-disk casing before listing that directory's children.
        parent="${partial_subdir%/*}"
        search_dir=$(_cdc_completion_resolve_case_path \
            "$wdir" "$parent" "$allow_hidden") || return 0
        root_dir=${wdir%/}
        root_dir=${root_dir##*/}
        candidate_prefix="$root_dir/${search_dir#"$wdir"/}/"
    else
        ##
        # No nested parent was typed, so list direct children of the matched
        # cdc root and prefix them with that root's basename.
        search_dir="$wdir"
        root_dir=${wdir%/}
        root_dir=${root_dir##*/}
        candidate_prefix="$root_dir/"
    fi

    [[ -d $search_dir ]] || return 0

    ##
    # Emit candidates in cdc syntax (`root/subdir`), not absolute paths.
    while IFS= read -r fulldir; do
        subdir=${fulldir%/}
        subdir=${subdir##*/}
        candidate="$candidate_prefix$subdir"

        if _cdc_completion_matches_current "$current" "$candidate"; then
            echo "$candidate"
        fi
    done < <(_cdc_child_dirs "$search_dir" "$allow_hidden")
}

##
# List directory completions for the current word.
#
# @param string $current
# @param boolean $allow_ignored
# @param boolean $repos_only
# @param boolean $parent_dirs
# @param boolean $allow_hidden
# @return string
_cdc_completion_list() {
    local current="$1"
    local allow_ignored="${2:-false}"
    local repos_only="${3:-${CDC_REPOS_ONLY:-false}}"
    local parent_dirs="${4:-false}"
    local allow_hidden="${5:-${CDC_ALLOW_HIDDEN:-false}}"
    local cd_dir
    local subdir
    local wdir

    ##
    # A slash means the user has selected a cdc root and is now completing
    # subdirectories under that match.
    if [[ $current == */* ]]; then
        cd_dir="${current%%/*}"
        subdir="${current#*/}"

        if [[ $parent_dirs == true ]]; then
            ##
            # -P switches the root candidate set from child dirs to configured
            # parent dirs.
            cd_dir=$(_cdc_completion_parent_list "$allow_ignored" \
                | _cdc_completion_select_match "$cd_dir") || return 0
            wdir=$(_cdc_find_parent_dir "$cd_dir" "$allow_ignored" false)
        else
            cd_dir=$(_cdc_completion_repo_list \
                "$allow_ignored" "$repos_only" "$allow_hidden" \
                | _cdc_completion_select_match "$cd_dir") || return 0
            wdir=$(_cdc_find_dir \
                "$cd_dir" "$allow_ignored" "$repos_only" false "$allow_hidden")
        fi

        (( $? == 0 )) || return 0

        _cdc_completion_subdir_list \
            "$current" "$cd_dir" "$wdir" "$subdir" "$allow_hidden"
        return 0
    fi

    if [[ $parent_dirs == true ]]; then
        ##
        # Without a slash, -P completes configured parent basenames.
        _cdc_completion_parent_list "$allow_ignored" \
            | _cdc_completion_filter "$current"
        return 0
    fi

    ##
    # Default completion lists child directories under CDC_DIRS.
    _cdc_completion_repo_list "$allow_ignored" "$repos_only" "$allow_hidden" \
        | _cdc_completion_filter "$current"
}
