##
# Completion function for the cdc plugin that lists repositories found in
# $CDC_DIRS that aren't excluded.
#
# @param string $string
# @return array
__cdc_repo_list() {
    local dir
    local subdir
    local directories=()

    ##
    # Loop through all elements of $CDC_DIRS array.
    for dir in "${CDC_DIRS[@]}"; do

        ##
        # If the element isn't a directory that exists, move on.
        if ! [[ -d $dir ]]; then
            if ! $CDC_QUIET; then
                printf "\nWarning: $dir is not a valid directory." >&2
            fi
            continue
        fi

        ##
        # If the directory exists, cd into it.
        cd "$dir"

        ##
        # Loop through all subdirectories in the directory.
        for subdir in */; do
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
