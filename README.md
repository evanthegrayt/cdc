# cdc [directory]
## Table of contents
- [Rationale](#rationale)
  - [Why the name "cdc"?](#why-the-name-cdc)
- [Installation](#installation)
  - [Oh-My-Zsh](#oh-my-zsh)
  - [Bash-It](#bash-it)
  - [Vanilla Zsh or Bash](#vanilla-zsh-or-bash)
- [Set-up](#set-up)
  - [Telling cdc where to look](#telling-cdc-where-to-look)
  - [Ignoring certain directories](#ignoring-certain-directories)
  - [Only recognize actual repositories](#only-recognize-actual-repositories)
  - [Automatically pushing to the history stack](#automatically-pushing-to-the-history-stack)
- [Usage](#usage)
  - [Options](#options)
- [Reporting Bugs](#reporting-bugs)

## Rationale
I have a few directories in which I clone repositories. This function will
change directory to the passed argument, no matter which of the
repository-containing directories it's in. The plugin comes with tab-completion
for its arguments, as long as your `zsh`/`bash` version supports it. The plugin
also includes session history, and has options available that behave similar to
the `popd` and `dirs` commands.

While this plugin was written for directories that contain `git` repositories,
you can obviously use it for adding any directory to your `cd` path.

It's worth noting that I chose to make this function rather than editing
`$CDPATH` because I don't like changing the default behavior of `cd`, but you
could just as easily do the
following:
```sh
# Assuming `other_repo` exists in `/path/to/repo_dir`
CDPATH=/path/to/repo_dir

cd other_repo # will cd to /path/to/repo_dir/other_repo
```

Alternatively, you could make aliases:

```sh
alias other_repo='cd /path/to/repo_dir/other_repo'
```

I don't like this method either, as it just pollutes your environment. In my
opinion, the less aliases, the better. Also, you now have to remember an alias
for each repository. `cdc` solves this issue with its tab-completion.

### Why the name "cdc"?
I wanted something fast to type that wasn't already a command or builtin. You
already type `cd` a million times a day, and you don't even have to move your
finger to hit the <kbd>c</kbd> key again. You can't get much faster.

## Installation
### oh-my-zsh
Clone the repository in your `$ZSH_CUSTOM/plugins` directory
```sh
git clone https://github.com/evanthegrayt/cdc.git $ZSH_CUSTOM/plugins/cdc
```
Then add the plugin to your `$HOME/.zshrc` file in the `plugins` array:
```sh
plugins=(cdc) # Obviously, leave your other plugins in the array.
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
The following settings require variables to be set from either a file called
`~/.cdcrc`, or a shell startup file such as `~/.zshrc` or `~/.bash_profile`. The
following instructions will default to using `~/.cdcrc`, but just know that you
have the other option.

Note that the `~/.cdcrc` file is just a shell script that sets values, so you
can use `bash` conditionals if you'd like to use the same config file on
multiple systems. You can view an example of this in [my config
file](https://github.com/evanthegrayt/dotfiles/blob/master/dotfiles/cdcrc). Just
remember, these files get sourced into your interactive shell on startup, so
only use it to set the following values.

### Telling cdc where to look
To use this plugin, you need to set `CDC_DIRS` in `~/.cdcrc`. It should be an
array with absolute paths to the directories to search.

```sh
# Set this in ~/.cdcrc
CDC_DIRS=($HOME/dir_with_repos $HOME/workspace/another_dir_with_repos)
```

Note that the order of the elements in the array matters. The plugin will `cd`
to the first match it finds, so if you have the same repository -- or two
repositories with the same name -- in two places, the first location in the
array will take precedence. There is currently an issue to better handle this...
feature. Not sure how I want to go about it yet. Suggestions are very much
welcome [on the issue](https://github.com/evanthegrayt/cdc/issues/6).

### Ignoring certain directories
If you have directories within `CDC_DIRS` that you want the plugin to ignore,
you can set `CDC_IGNORE` to an array containing those directories. These
elements should only be the directory base-name, **not** the absolute path.
"Ignoring" a directory will prevent it from being "seen" by `cdc`.

```sh
# Assuming you never want to `cdc notes_directory`:
CDC_IGNORE=(notes_directory)
```

### Only recognize actual repositories
You can set `CDC_REPOS_ONLY` in `~/.cdcrc` to make `cdc` only recognize
repositories as directories. This is **disabled by default**. You can also set
an array of files and directories that mark what you consider a repository.

```sh
# Enable "repos-only" mode. Note, the default is false.
CDC_REPOS_ONLY=true
# Set repository markers with the following. Note, the following is already the
# default, but this is how you can add more in ~/.cdcrc
CDC_REPO_MARKERS=(.git .git/ Rakefile Makefile .hg/ .bzr/ .svn/)
```

Note that this setting can be overridden with the `-r` and `-R` options. See
[options](#options) below.

### Automatically pushing to the history stack
By default, every `cdc` call will push the directory onto the history stack. You
can disable this feature by setting `CDC_AUTO_PUSH` to `false` in your
`~/.cdcrc`.

```sh
# Disable auto-pushing to history stack.
CDC_AUTO_PUSH=false
```

You can then manually push directories onto the stack with `-u`. If you have
`CDC_AUTO_PUSH` set to `true`, you can still `cdc` to a directory and not push
it to the stack with the `-U` option. See [options](#options) below.

## Usage
Typing `cdc <TAB>` will list all available directories, and this list is built
on the fly; nothing is hard-coded. Hit `return` after typing the directory name
to change to that directory.

You *can* append subdirectories, and it will work; however, this is an
experimental feature, and I don't have tab-autocompletion working for this yet
(any help with [the issue](https://github.com/evanthegrayt/cdc/issues/2) would
be greatly appreciated). For example:

```sh
cdc dir_with_repos/bin
```

If the subdirectory doesn't exist, it will `cd` to the base directory, and then
print a message to `stderr`.

### Options
The plugin comes with a few available options. Most are for dealing with the
directory history stack, similar to `pushd`, `popd`, and `dirs`. There's also a
debug mode.

|Flag|What it does|
|:------|:-----------|
|-l|List all directories that you can `cdc` to. Same as tab-completion.|
|-d|List directories in history stack. Similar to the `dirs` command.|
|-c|`cd` to the current directory in the history stack.|
|-t|Toggle to the last directory, similar to `cd -`. Rearranges history stack.|
|-p|`cd` to previous directory in history stack. Similar to the `popd` command.|
|-u|Push the directory onto the stack when `CDC_AUTO_PUSH=false`.|
|-U|Do *not* push the directory onto the stack when `CDC_AUTO_PUSH=true`.|
|-r|Only `cdc` to repositories. Overrides `$CDC_REPOS_ONLY`|
|-R|`cd` to any directory, even it's not a repository. Overrides `$CDC_REPOS_ONLY`|
|-D|Debug mode. Enables warnings for when things aren't working as expected.|
|-h|Print help.|

There is no option to push to the stack, as this is done automatically with each
`cdc` call. If you want that behavior, consider just using the actual `pushd`
and `popd` commands. If you *really* want this behavior, let me know by
[creating an issue](https://github.com/evanthegrayt/cdc/issues/new).

## Reporting bugs
If you have an idea or find a bug, please [create an
issue](https://github.com/evanthegrayt/cdc/issues/new). Just make sure the topic
doesn't already exist. Better yet, you can always submit a Pull Request.

If you have an issue with tab-completion, make sure you have completion enabled
for your shell
([bash](https://www.gnu.org/software/bash/manual/html_node/Programmable-Completion.html)
/ [zsh](http://zsh.sourceforge.net/Doc/Release/Completion-System.html)). If,
after reading the manual, you still have problems, feel free to submit an issue.

