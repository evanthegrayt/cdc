##
# The file to be sourced if you're using zsh and want tab-completion.

##
# Source the plugin and completion functions.
# In zsh, ${0:h} expands to the directory containing this sourced file.
source "${0:h}/cdc.sh"

##
# Load zsh's completion system when a framework has not already done so.
# $+functions[name] is 1 when a function is defined and 0 when it is not.
if ! (( $+functions[compdef] )); then
  # compinit defines compdef/compadd and prepares zsh's completion tables.
  autoload -Uz compinit
  compinit -D -i
fi

##
# Add completion arguments.
_cdc_complete_options() {
  local -a options
  local -a descriptions

  # ${(f)...} splits command output on newlines; (@) keeps array elements intact.
  options=("${(@f)$(_cdc_completion_all_options)}")
  descriptions=("${(@f)$(_cdc_completion_option_descriptions)}")

  # compadd adds completion candidates. -d supplies display descriptions.
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

  # zsh provides words/CURRENT during completion; arrays are 1-indexed.
  cur="${words[CURRENT]}"

  # Capture arguments before the word being completed, excluding the command.
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

  # _cdc_completion_mode prints three newline-separated booleans.
  mode=($(_cdc_completion_mode "${args[@]}"))
  allow_ignored="${mode[1]}"
  repos_only="${mode[2]}"
  parent_dirs="${mode[3]}"
  # Keep each newline-separated candidate as a single completion entry.
  candidates=("${(@f)$(_cdc_completion_list "$cur" "$allow_ignored" "$repos_only" "$parent_dirs")}")

  # -M makes matching case-insensitive; -S '' prevents an appended space.
  (( ${#candidates[@]} )) && compadd -M 'm:{a-zA-Z}={A-Za-z}' -S '' -- "${candidates[@]}"
}

##
# Define completions.
# Register _cdc as the completion function for the cdc command.
compdef '_cdc' cdc
