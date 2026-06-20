##
# The file to be sourced if you're using zsh and want tab-completion.

##
# Source the plugin and completion functions.
source "${0:h}/cdc.sh"

##
# Add completion arguments.
_cdc_complete_options() {
  local -a options
  local -a descriptions

  options=("${(@f)$(_cdc_completion_all_options)}")
  descriptions=("${(@f)$(_cdc_completion_option_descriptions)}")

  compadd -d descriptions -- "${options[@]}"
}

_cdc() {
  local cur
  local i
  local allow_ignored
  local repos_only
  local parent_dirs
  local -a args
  local -a candidates
  local -a mode

  cur="${words[CURRENT]}"

  i=2
  while (( i < CURRENT )); do
    args+=("${words[i]}")
    (( i += 1 ))
  done

  if _cdc_completion_has_terminal_action "${args[@]}"; then
    return
  fi

  if _cdc_completion_has_operand "${args[@]}"; then
    return
  fi

  if [[ $cur == -* ]]; then
    _cdc_complete_options
    return
  fi

  mode=($(_cdc_completion_mode "${args[@]}"))
  allow_ignored="${mode[1]}"
  repos_only="${mode[2]}"
  parent_dirs="${mode[3]}"
  candidates=("${(@f)$(_cdc_completion_list "$cur" "$allow_ignored" "$repos_only" "$parent_dirs")}")

  (( ${#candidates[@]} )) && compadd -S '' -- "${candidates[@]}"
}

##
# Define completions.
compdef '_cdc' cdc
