cdc_project_root() {
    cd "$BATS_TEST_DIRNAME/.." >/dev/null 2>&1
    pwd
}

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
    unset CDC_CURRENT

    source "$CDC_PROJECT_ROOT/cdc.sh"
    cd "$CDC_FIXTURE/start"
}

assert_success() {
    [ "$status" -eq 0 ]
}

assert_failure_status() {
    [ "$status" -eq "$1" ]
}

assert_output_contains() {
    [[ "$output" == *"$1"* ]]
}

assert_output_not_contains() {
    [[ "$output" != *"$1"* ]]
}

assert_file_equals() {
    [ "$(cat "$1")" = "$2" ]
}

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

git_fixture_commit() {
    local dir="$1"
    local file="$2"
    local message="$3"

    git -C "$dir" add "$file"
    git -C "$dir" commit -qm "$message"
}
