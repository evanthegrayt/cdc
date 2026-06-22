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
# @return string
_cdc_completion_resolve_case_path() {
    local base_dir="$1"
    local subdir_path="$2"
    local resolved="$base_dir"
    local remaining="$subdir_path"
    local segment
    local fulldir
    local fulldir_name
    local candidate

    while [[ -n $remaining ]]; do
        if [[ $remaining == */* ]]; then
            segment="${remaining%%/*}"
            remaining="${remaining#*/}"
        else
            segment="$remaining"
            remaining=""
        fi

        [[ -n $segment ]] || continue

        candidate=""
        for fulldir in "$resolved"/*/; do
            [[ -d $fulldir ]] || continue

            fulldir_name=${fulldir%/}
            fulldir_name=${fulldir_name##*/}

            if _cdc_completion_matches_exact "$segment" "$fulldir_name"; then
                candidate="${fulldir%/}"
                break
            fi
        done

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
# @return string
_cdc_completion_subdir_list() {
    local current="$1"
    local cd_dir="$2"
    local wdir="$3"
    local partial_subdir="$4"
    local root_dir
    local parent
    local search_dir
    local candidate_prefix
    local fulldir
    local subdir
    local candidate

    if [[ $partial_subdir == */* ]]; then
        parent="${partial_subdir%/*}"
        search_dir=$(_cdc_completion_resolve_case_path "$wdir" "$parent") || return 0
        root_dir=${wdir%/}
        root_dir=${root_dir##*/}
        candidate_prefix="$root_dir/${search_dir#"$wdir"/}/"
    else
        search_dir="$wdir"
        root_dir=${wdir%/}
        root_dir=${root_dir##*/}
        candidate_prefix="$root_dir/"
    fi

    [[ -d $search_dir ]] || return 0

    for fulldir in "$search_dir"/*/; do
        [[ -d $fulldir ]] || continue

        subdir=${fulldir%/}
        subdir=${subdir##*/}
        candidate="$candidate_prefix$subdir"

        if _cdc_completion_matches_current "$current" "$candidate"; then
            echo "$candidate"
        fi
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
            cd_dir=$(_cdc_completion_parent_list "$allow_ignored" \
                | _cdc_completion_select_match "$cd_dir") || return 0
            wdir=$(_cdc_find_parent_dir "$cd_dir" "$allow_ignored" false)
        else
            cd_dir=$(_cdc_completion_repo_list "$allow_ignored" "$repos_only" \
                | _cdc_completion_select_match "$cd_dir") || return 0
            wdir=$(_cdc_find_dir "$cd_dir" "$allow_ignored" "$repos_only" false)
        fi

        (( $? == 0 )) || return 0

        _cdc_completion_subdir_list "$current" "$cd_dir" "$wdir" "$subdir"
        return 0
    fi

    if [[ $parent_dirs == true ]]; then
        _cdc_completion_parent_list "$allow_ignored" \
            | _cdc_completion_filter "$current"
        return 0
    fi

    _cdc_completion_repo_list "$allow_ignored" "$repos_only" \
        | _cdc_completion_filter "$current"
}
