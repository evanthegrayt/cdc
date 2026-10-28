# Bats supplies status and output after each run invocation.
# shellcheck disable=SC2154

##
# Print the repository root containing the test suite.
#
# @return string
cdc_project_root() {
    cd "$BATS_TEST_DIRNAME/.." >/dev/null 2>&1 || return 1
    pwd
}

##
# Create isolated directories and configure the test shell.
#
# @return boolean
setup_cdc_fixture() {
    CDC_PROJECT_ROOT="$(cdc_project_root)"
    CDC_FIXTURE="$BATS_TEST_TMPDIR/cdc fixture"
    CDC_HOME="$CDC_FIXTURE/home"

    mkdir -p "$CDC_HOME"
    mkdir -p "$CDC_FIXTURE/one/repo/.git"
    mkdir -p "$CDC_FIXTURE/one/repo/bin"
    mkdir -p "$CDC_FIXTURE/one/repo/.cache/data"
    mkdir -p "$CDC_FIXTURE/one/.hidden"
    mkdir -p "$CDC_FIXTURE/one/MixedCase/.git"
    mkdir -p "$CDC_FIXTURE/one/MixedCase/bin"
    mkdir -p "$CDC_FIXTURE/one/repo with space/.git"
    mkdir -p "$CDC_FIXTURE/one/repo with space/bin"
    mkdir -p "$CDC_HOME/.vim/pack"
    mkdir -p "$CDC_HOME/plain/subdir"
    mkdir -p "$CDC_FIXTURE/two/repo/.git"
    mkdir -p "$CDC_FIXTURE/two/ignored"
    mkdir -p "$CDC_FIXTURE/two/ignored with space"
    mkdir -p "$CDC_FIXTURE/two/plain"
    mkdir -p "$CDC_FIXTURE/three/custom"
    mkdir -p "$CDC_FIXTURE/start"
    touch "$CDC_FIXTURE/three/custom/Rakefile"

    export HOME="$CDC_HOME"
    export CDC_DIRS="$CDC_FIXTURE/one:$CDC_FIXTURE/two:$CDC_FIXTURE/three"
    export CDC_IGNORE=ignored
    export CDC_REPOS_ONLY=false
    unset CDC_REPO_MARKERS
    unset CDC_AUTO_PUSH
    unset CDC_IGNORE_DUPS
    unset CDC_EXPLICIT_DIRS
    unset CDC_COLOR
    unset CDC_ALLOW_HIDDEN
    export CDC_CHOICES_FILE="$CDC_FIXTURE/cache/choices"
    unset CDC_COLLISION_MODE
    unset CDC_CURRENT

    source "$CDC_PROJECT_ROOT/cdc.sh"
    cd "$CDC_FIXTURE/start" || return 1
}

##
# Assert that the last Bats command succeeded.
#
# @return boolean
assert_success() {
    [ "$status" -eq 0 ]
}

##
# Assert the exit status of the last Bats command.
#
# @param integer $expected
# @return boolean
assert_failure_status() {
    [ "$status" -eq "$1" ]
}

##
# Assert that command output contains a literal substring.
#
# @param string $expected
# @return boolean
assert_output_contains() {
    [[ "$output" == *"$1"* ]]
}

##
# Assert that command output excludes a literal substring.
#
# @param string $unexpected
# @return boolean
assert_output_not_contains() {
    [[ "$output" != *"$1"* ]]
}

##
# Assert that file contents equal the expected text.
#
# @param string $file
# @param string $expected
# @return boolean
assert_file_equals() {
    [ "$(cat "$1")" = "$2" ]
}

##
# Initialize a fixture repository with one commit.
#
# @param string $dir
# @return boolean
git_fixture_repo() {
    local dir="$1"

    mkdir -p "$dir"
    git -C "$dir" init -q
    git -C "$dir" config user.name "cdc tests"
    git -C "$dir" config user.email "cdc@example.test"
    printf "initial\n" > "$dir/README.md"
    git -C "$dir" add README.md
    git -C "$dir" commit -qm "initial"
}

##
# Commit a fixture file with the supplied message.
#
# @param string $dir
# @param string $file
# @param string $message
# @return boolean
git_fixture_commit() {
    local dir="$1"
    local file="$2"
    local message="$3"

    git -C "$dir" add "$file"
    git -C "$dir" commit -qm "$message"
}
