DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/cdc.sh

if [[ -n $BASH_IT ]]; then
    cite about-plugin
    about-plugin 'easily `cd` to common repos from anywhere'
fi

complete -W "$( _cdc_repo_list )" cdc

