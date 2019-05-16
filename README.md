# cdc [directory]
I have a few directories in which I clone repositories. This function will
change directory to the passed arguement, no matter which directory it's in,
complete with tab-completion for its arguments (although this currently only
works if you're using `.oh-my-zsh`. There is an issue to update this when I have
the time).

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
with vanilla `zsh`, or even [bash-it](https://github.com/Bash-it/bash-it)
or vanilla `bash` (with the exception of tab-completion).

### oh-my-zsh
Clone the repository in your `$ZSH_CUSTOM/plugins` directory
```sh
git clone https://github.com/evanthegrayt/cdc.git $ZSH_CUSTOM/plugins/cdc
```
Then add the plugin to your `$HOME/.zshrc` file in the `plugins` array:
```sh
plugins=(cdc) # Obviously, leave your other plugins in the array
```

### bash-it
Clone the repository in your `$BASH_IT_CUSTOM` directory
```sh
git clone https://github.com/evanthegrayt/cdc.git $BASH_IT_CUSTOM/cdc
```
Files in this directory that end with `.bash` are automatically sourced, so
there's nothing else to do.

### Vanilla zsh or bash
Just source either the `cdc.plugin.zsh` file for `zsh`, or `cdc.plugin.bash`
file for `bash`, from one of your startup files, such as `~/.zshrc` or
`~/.bashrc`.s

If the argument completion doesn't work for `zsh`, try adding the
directory to your `fpath` array.
```sh
fpath+=(/path/to/cdc)
```
If it still doesn't work, please add your pertinent config info to [this
issue](https://github.com/evanthegrayt/cdc/issues/4) in a comment.

## Set-up
To use this feature, you need to set `CDC_DIRS` in either a startup file (such
as `~/.zshrc`), or a file called `$HOME/.cdcrc`. It should be an array with
absolute paths to the directories to search.

```sh
# Set this in either `~/.zshrc` (or similar), or in `~/.cdcrc`
CDC_DIRS=($HOME/dir_with_repos $HOME/workspace/repos)
```

If you have directories within `CDC_DIRS` that you want the plugin to ignore,
such as a notes directory, you can also set `CDC_IGNORE` to an array, containing
directories to ignore. These elements should only be the directory base-name,
not the absolute path.

```sh
# Set this in either `~/.zshrc` (or similar), or in `~/.cdcrc`. Assuming you
# never want to `cdc notes_directory`
CDC_IGNORE=(notes_directory)
```

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
If the subdirectory doesn't exist, it will `cd` to the base directory, and then
print a message to `stderr`.

## Reporting bugs
This program is under development, so if you have an idea or find a bug, please
[create an issue](https://github.com/evanthegrayt/cdc/issues/new). Just make
sure the topic doesn't already exist.

