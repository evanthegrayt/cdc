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

  options=(
    -a -c -C -D -d -h -i -L -l -n -p -P -R -r -t -U -u -w
  )

  descriptions=(
    '-a  cd to the directory even if it is ignored'
    '-c  Enable colored output'
    '-C  Disable colored output'
    '-D  Enable debug mode for unexpected behavior'
    '-d  List the directories in the stack'
    '-h  Print this help'
    '-i  List ignored directories'
    '-L  List directories that cdc searches'
    '-l  List cdc-able directories'
    '-n  cd to the current directory in the stack'
    '-p  cd to the previous directory and pop it from the stack'
    '-P  cd to a configured parent directory'
    '-R  cd to any directory, even if it is not a repository'
    '-r  Only cd to repositories'
    '-t  Toggle between the last two directories in the stack'
    '-U  Do not push the directory onto the stack'
    '-u  Push the directory onto the stack'
    '-w  Print the directory location instead of changing to it'
  )

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
    (( i++ ))
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
