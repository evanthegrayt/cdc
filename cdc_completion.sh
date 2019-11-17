##
# Completion functions for the cdc plugin.

##
# Returns "true" if argument is an element in $CDC_IGNORE.
#
# @param string $string
# @return boolean
_cdc_is_excluded_dir() {
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
# List of repositories found in $CDC_DIRS that aren't excluded.
#
# @param string $string
# @return array
_cdc_repo_list() {
    local dir
    local subdir
    local directories=()

    ##
    # Loop through all elements of $CDC_DIRS array.
    for dir in "${CDC_DIRS[@]}"; do

        ##
        # If the element isn't a directory that exists, move on.
        if ! [[ -d $dir ]]; then
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
            if ! _cdc_is_excluded_dir "$subdir"; then
                directories+=("$subdir")
            fi
        done
    done

    ##
    # "Return" the array.
    echo "${directories[@]}"
}
