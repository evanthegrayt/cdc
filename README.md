# cdc [directory]
I have a few directories in which I clone repositories. This function will
change directory to the passed arguement, no matter which directory it's in,
complete with tab-completion for its arguments (if you're using `zsh`).

I chose to make this function rather than editing `$CDPATH` because I don't like
changing the default bahavior of `cd`, but you could just as easily do the
following:

```sh
CDPATH=/path/to/repo:/path/to/other_repo

cd other_repo
```

## Installation
I wrote this function as an
[oh-my-zsh](https://github.com/robbyrussell/oh-my-zsh) plugin, but it will work
with vanilla `zsh`, or even `bash`.

### oh-my-zsh
Clone the repository in your `$ZSH_CUSTOM/plugins` directory
```sh
git clone https://github.com/evanthegrayt/cdc.git $ZSH_CUSTOM/plugins/cdc
```
Then add the plugin to your `$HOME/.zshrc` file in the `plugins` array:
```sh
plugins=(cdc) # Obviously, leave your other plugins in the array
```

### Vanilla zsh or bash
TODO: Add installation instructions for non-`oh-my-zsh` platforms.

## Set-up
To use this feature, you need to either export `CDC_DIRS` as an environmental
variable, or create a file called `$HOME/.cdcrc`, and create the array in that
file. It should be an array with absolute paths to the directories to
search.

```sh
# ENVIRONMENTAL VARIABLE EXAMPLE; this line would go in .zshrc or some other
# start-up config file
export CDC_DIRS=($HOME/dir_with_repos $HOME/workspace/repos)

# RC FILE EXAMPLE; this line would go in `$HOME/.cdcrc`
CDC_DIRS=($HOME/dir_with_repos $HOME/workspace/repos)
```

I chose to allow both methods because some people prefer not to pollute their
environment, and some poeple don't like creating a lot of dotfiles in their home
directory. I prefer to create the files, but feel free to choose the method you
prefer.

## Usage
Typing `cdc <TAB>` will list all available directories, and this list is built
on the fly; nothing is hard-coded. Hit `return` after typing the directory name
to change to that directory.

You *can* append subdirectories, and it will work; however, I don't have
tab-autocompletion working for this yet. For example:
```sh
# Assuming the following:
CDC_DIRS=($HOME/dir_with_repos)

# and `dir_with_repos` has a subdirectory called `bin`, you can:
cdc dir_with_repos/bin
```

