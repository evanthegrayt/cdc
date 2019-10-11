DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/cdc.sh
source $DIR/cdc_completion_functions.sh
unset DIR

if [[ -n $BASH_IT ]]; then
    cite about-plugin
    about-plugin '`cd` to directories from anywhere without chaning $CDPATH'
fi

complete -o nospace -W "$( _cdc_repo_list )" cdc

