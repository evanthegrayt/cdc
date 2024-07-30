##
# The file to be sourced if you're using bash and want tab-completion.
CDC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

##
# Source the plugin and completion functions.
source $CDC_DIR/cdc.sh
unset CDC_DIR

##
# Bash-it plugin citations.
if [[ -n $BASH_IT ]]; then
    cite about-plugin
    about-plugin '`cd` to directories from anywhere without changing $CDPATH'
fi

##
# Add completion arguments.
complete -o nospace -W "$( _cdc_repo_list )" cdc
