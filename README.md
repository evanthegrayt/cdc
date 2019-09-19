# cdc [directory]
I have a few directories in which I clone repositories. This function will
change directory to the passed argument, no matter which of the
repository-containing directories it's in. Comes with tab-completion for its
arguments, as long as your `zsh`/`bash` version supports it.

## Rationale
I chose to make this function rather than editing `$CDPATH` because I don't like
changing the default behavior of `cd`, but you could just as easily do the
following:
```sh
# Assuming `other_repo` exists in `/path/to/repo_dir`
CDPATH=/path/to/repo_dir

cd other_repo # will cd to /path/to/repo_dir/other_repo
```

## Installation
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
Clone the repository wherever you like, and source either the `cdc.plugin.zsh`
file for `zsh`, or `cdc.plugin.bash` file for `bash`, from one of your startup
files, such as `~/.zshrc` or `~/.bashrc`, respectively.

```sh
# Where $INSTALLATION_PATH is the path to where you installed the plugin.
source $INSTALLATION_PATH/cdc.plugin.zsh  # in ~/.zshrc
source $INSTALLATION_PATH/cdc.plugin.bash # in ~/.bashrc
```

If you're using a version of `zsh`/`bash` that doesn't support the completion
features, or you just don't want to use them, just source the `cdc.sh` file
directly.

```sh
source $INSTALLATION_PATH/cdc.sh # in either ~/.zshrc or ~/.bashrc
```

## Set-up
To use this feature, you need to set `CDC_DIRS` in either a startup file (such
as `~/.zshrc`), or a file called `~/.cdcrc`. It should be an array with
absolute paths to the directories to search.

```sh
# Set this in either `~/.zshrc` (or similar), or in `~/.cdcrc`
CDC_DIRS=($HOME/dir_with_repos $HOME/workspace/another_dir_with_repos)
```

If you have directories within `CDC_DIRS` that you want the plugin to ignore,
you can also set `CDC_IGNORE` to an array containing directories to ignore.
These elements should only be the directory base-name, **not** the absolute
path. "Ignoring" a directory will prevent it from being `cdc`'d to, and from
showing up in auto-completion.

```sh
# Set this in either `~/.zshrc` (or similar), or in `~/.cdcrc`.
# Assuming you never want to `cdc notes_directory`:
CDC_IGNORE=(notes_directory)
```

## Usage
Typing `cdc <TAB>` will list all available directories, and this list is built
on the fly; nothing is hard-coded. Hit `return` after typing the directory name
to change to that directory.

You *can* append subdirectories, and it will work; however, I don't have
tab-autocompletion working for this yet (any help with that would be
appreciated). For example:
```sh
cdc dir_with_repos/bin
```
If the subdirectory doesn't exist, it will `cd` to the base directory, and then
print a message to `stderr`.

## Reporting bugs
If you have an idea or find a bug, please [create an
issue](https://github.com/evanthegrayt/cdc/issues/new). Just make sure the topic
doesn't already exist.

