#!/usr/bin/env bats

load helpers/cdc

setup() {
    setup_cdc_fixture
}

@test "cdc changes to the first matching directory and pushes history" {
    cdc repo

    [ "$PWD" = "$CDC_FIXTURE/one/repo" ]
    [ "${#CDC_HISTORY[@]}" -eq 1 ]
    [ "${CDC_HISTORY[0]}" = "$CDC_FIXTURE/one/repo" ]
}

@test "cdc -w prints the match without changing directories" {
    cdc -w repo >"$BATS_TEST_TMPDIR/which.out"

    assert_file_equals "$BATS_TEST_TMPDIR/which.out" "$CDC_FIXTURE/one/repo"
    [ "$PWD" = "$CDC_FIXTURE/start" ]
    [ "${#CDC_HISTORY[@]}" -eq 0 ]
}

@test "cdc -U changes directories without pushing history" {
    cdc -U repo

    [ "$PWD" = "$CDC_FIXTURE/one/repo" ]
    [ "${#CDC_HISTORY[@]}" -eq 0 ]
}

@test "cdc -P changes to a configured parent directory" {
    cdc -P one

    [ "$PWD" = "$CDC_FIXTURE/one" ]
    [ "${#CDC_HISTORY[@]}" -eq 1 ]
    [ "${CDC_HISTORY[0]}" = "$CDC_FIXTURE/one" ]
}

@test "cdc -P supports subdirectories under a configured parent directory" {
    cdc -P two/plain

    [ "$PWD" = "$CDC_FIXTURE/two/plain" ]
    [ "${#CDC_HISTORY[@]}" -eq 1 ]
    [ "${CDC_HISTORY[0]}" = "$CDC_FIXTURE/two" ]
}

@test "cdc respects ignored directories unless -a is passed" {
    run cdc -w ignored
    assert_failure_status 2
    [ "$output" = "[ignored] not found." ]

    cdc -a -w ignored >"$BATS_TEST_TMPDIR/ignored.out"
    assert_file_equals "$BATS_TEST_TMPDIR/ignored.out" "$CDC_FIXTURE/two/ignored"
}

@test "repo-only mode can be enabled by env and overridden by -R" {
    export CDC_REPOS_ONLY=true

    run cdc -w plain
    assert_failure_status 2
    [ "$output" = "[plain] not found." ]

    cdc -R -w plain >"$BATS_TEST_TMPDIR/plain.out"
    assert_file_equals "$BATS_TEST_TMPDIR/plain.out" "$CDC_FIXTURE/two/plain"
}

@test "repo-only mode can be enabled with -r" {
    run cdc -r -w plain
    assert_failure_status 2
    [ "$output" = "[plain] not found." ]
}

@test "repo markers can be configured" {
    export CDC_REPOS_ONLY=true
    export CDC_REPO_MARKERS=Rakefile

    cdc -w custom >"$BATS_TEST_TMPDIR/custom.out"

    assert_file_equals "$BATS_TEST_TMPDIR/custom.out" "$CDC_FIXTURE/three/custom"
}

@test "cdc supports documented subdirectory navigation" {
    cdc repo/bin

    [ "$PWD" = "$CDC_FIXTURE/one/repo/bin" ]
    [ "${#CDC_HISTORY[@]}" -eq 1 ]
    [ "${CDC_HISTORY[0]}" = "$CDC_FIXTURE/one/repo" ]
}

@test "cdc supports repo roots and repo names with spaces" {
    cdc -w "repo with space" >"$BATS_TEST_TMPDIR/space-repo.out"
    assert_file_equals "$BATS_TEST_TMPDIR/space-repo.out" "$CDC_FIXTURE/one/repo with space"

    cdc "repo with space/bin"

    [ "$PWD" = "$CDC_FIXTURE/one/repo with space/bin" ]
    [ "${#CDC_HISTORY[@]}" -eq 1 ]
    [ "${CDC_HISTORY[0]}" = "$CDC_FIXTURE/one/repo with space" ]
}

@test "cdc handles ignored names with spaces" {
    export CDC_IGNORE="ignored:ignored with space"

    run cdc -w "ignored with space"
    assert_failure_status 2
    [ "$output" = "[ignored with space] not found." ]

    cdc -a -w "ignored with space" >"$BATS_TEST_TMPDIR/ignored-space.out"
    assert_file_equals "$BATS_TEST_TMPDIR/ignored-space.out" "$CDC_FIXTURE/two/ignored with space"
}

@test "history pop changes to the previous directory" {
    cdc repo
    cdc plain
    cdc -p

    [ "$PWD" = "$CDC_FIXTURE/one/repo" ]
    [ "${#CDC_HISTORY[@]}" -eq 1 ]
    [ "${CDC_HISTORY[0]}" = "$CDC_FIXTURE/one/repo" ]
}

@test "history toggle flips between the last two directories" {
    cdc repo
    cdc plain

    cdc -t
    [ "$PWD" = "$CDC_FIXTURE/one/repo" ]

    cdc -t
    [ "$PWD" = "$CDC_FIXTURE/two/plain" ]
}

@test "history list prints repository base names" {
    cdc repo
    cdc "repo with space"

    run cdc -d

    assert_success
    [ "$output" = "repo repo with space " ]
}

@test "list options print configured directories" {
    run cdc -L
    assert_success
    assert_output_contains "$CDC_FIXTURE/one"
    assert_output_contains "$CDC_FIXTURE/two"
    assert_output_contains "$CDC_FIXTURE/three"

    run cdc -i
    assert_success
    [ "$output" = "ignored" ]

    run cdc -l
    assert_success
    assert_output_contains "repo"
    assert_output_contains "plain"
    assert_output_contains "custom"
}

@test "help output includes option descriptions" {
    run cdc -h

    assert_success
    assert_output_contains "-P"
    assert_output_contains "cd to a configured parent directory"
    assert_output_contains "-R"
    assert_output_contains "cd to any directory, even if it is not a repository"
}

@test "cdc requires CDC_DIRS" {
    unset CDC_DIRS

    run cdc repo

    assert_failure_status 1
    [ "$output" = "You must set CDC_DIRS in a config file" ]
}

@test "zsh plugin wrapper loads cdc when completion is available" {
    export CDC_PROJECT_ROOT

    run zsh -c '
        compdef() { :; }
        source "$CDC_PROJECT_ROOT/cdc.plugin.zsh"
        whence -w cdc
    '

    assert_success
    assert_output_contains "cdc: function"
}

@test "bash plugin wrapper loads cdc" {
    export CDC_PROJECT_ROOT

    run bash -c '
        source "$CDC_PROJECT_ROOT/cdc.plugin.bash"
        type cdc
    '

    assert_success
    assert_output_contains "cdc is a function"
}

@test "bash plugin wrapper loads cdc from a plugin directory with spaces" {
    PLUGIN_WITH_SPACE="$BATS_TEST_TMPDIR/plugin with space"
    export PLUGIN_WITH_SPACE
    mkdir -p "$PLUGIN_WITH_SPACE"
    cp "$CDC_PROJECT_ROOT/cdc.sh" "$CDC_PROJECT_ROOT/cdc.plugin.bash" "$PLUGIN_WITH_SPACE"

    run bash -c '
        source "$PLUGIN_WITH_SPACE/cdc.plugin.bash"
        type cdc
    '

    assert_success
    assert_output_contains "cdc is a function"
}

@test "bash completion completes cdc subdirectories" {
    export CDC_PROJECT_ROOT

    run bash -c '
        source "$CDC_PROJECT_ROOT/cdc.plugin.bash"

        COMP_WORDS=(cdc repo/)
        COMP_CWORD=1
        _cdc_complete
        printf "%s\n" "${COMPREPLY[@]}"
    '

    assert_success
    assert_output_contains "repo/bin"
}

@test "bash completion preserves candidates with spaces" {
    export CDC_PROJECT_ROOT

    run bash -c '
        source "$CDC_PROJECT_ROOT/cdc.plugin.bash"

        COMP_WORDS=(cdc "repo with")
        COMP_CWORD=1
        _cdc_complete
        printf "%s\n" "${COMPREPLY[@]}"
    '

    assert_success
    assert_output_contains "repo with space"
}

@test "bash completion applies directory-affecting flags" {
    export CDC_PROJECT_ROOT
    export CDC_REPOS_ONLY=true

    run bash -c '
        source "$CDC_PROJECT_ROOT/cdc.plugin.bash"

        COMP_WORDS=(cdc -R "")
        COMP_CWORD=2
        _cdc_complete
        printf "%s\n" "${COMPREPLY[@]}"
    '

    assert_success
    assert_output_contains "plain"

    export CDC_REPOS_ONLY=false

    run bash -c '
        source "$CDC_PROJECT_ROOT/cdc.plugin.bash"

        COMP_WORDS=(cdc -r "")
        COMP_CWORD=2
        _cdc_complete
        printf "%s\n" "${COMPREPLY[@]}"
    '

    assert_success
    assert_output_not_contains "plain"
}

@test "bash completion lists configured parents with -P" {
    export CDC_PROJECT_ROOT

    run bash -c '
        source "$CDC_PROJECT_ROOT/cdc.plugin.bash"

        COMP_WORDS=(cdc -P "")
        COMP_CWORD=2
        _cdc_complete
        printf "%s\n" "${COMPREPLY[@]}"
    '

    assert_success
    assert_output_contains "one"
    assert_output_contains "two"
    assert_output_contains "three"
    assert_output_not_contains "repo"
    assert_output_not_contains "plain"
    assert_output_not_contains "custom"
}

@test "bash completion suppresses directory operands after action flags" {
    export CDC_PROJECT_ROOT

    run bash -c '
        source "$CDC_PROJECT_ROOT/cdc.plugin.bash"

        COMP_WORDS=(cdc -p "")
        COMP_CWORD=2
        _cdc_complete
        printf "%s\n" "${COMPREPLY[@]}"
    '

    assert_success
    [ "$output" = "" ]
}

@test "zsh completion completes cdc subdirectories" {
    export CDC_PROJECT_ROOT

    run zsh -c '
        compdef() { :; }
        compadd() {
            local arg
            for arg in "$@"; do
                case "$arg" in
                    -S|--|"") continue ;;
                    *) print -r -- "$arg" ;;
                esac
            done
        }

        source "$CDC_PROJECT_ROOT/cdc.plugin.zsh"

        words=(cdc repo/)
        CURRENT=2
        _cdc
    '

    assert_success
    assert_output_contains "repo/bin"
}

@test "zsh completion preserves candidates with spaces" {
    export CDC_PROJECT_ROOT

    run zsh -c '
        compdef() { :; }
        compadd() {
            local arg
            for arg in "$@"; do
                case "$arg" in
                    -S|--|"") continue ;;
                    *) print -r -- "$arg" ;;
                esac
            done
        }

        source "$CDC_PROJECT_ROOT/cdc.plugin.zsh"

        words=(cdc "repo with")
        CURRENT=2
        _cdc
    '

    assert_success
    assert_output_contains "repo with space"
}

@test "zsh completion applies directory-affecting flags" {
    export CDC_PROJECT_ROOT
    export CDC_REPOS_ONLY=true

    run zsh -c '
        compdef() { :; }
        compadd() {
            local arg
            for arg in "$@"; do
                case "$arg" in
                    -S|--|"") continue ;;
                    *) print -r -- "$arg" ;;
                esac
            done
        }

        source "$CDC_PROJECT_ROOT/cdc.plugin.zsh"

        words=(cdc -R "")
        CURRENT=3
        _cdc
    '

    assert_success
    assert_output_contains "plain"

    export CDC_REPOS_ONLY=false

    run zsh -c '
        compdef() { :; }
        compadd() {
            local arg
            for arg in "$@"; do
                case "$arg" in
                    -S|--|"") continue ;;
                    *) print -r -- "$arg" ;;
                esac
            done
        }

        source "$CDC_PROJECT_ROOT/cdc.plugin.zsh"

        words=(cdc -r "")
        CURRENT=3
        _cdc
    '

    assert_success
    assert_output_not_contains "plain"
}

@test "zsh completion lists configured parents with -P" {
    export CDC_PROJECT_ROOT

    run zsh -c '
        compdef() { :; }
        compadd() {
            local arg
            for arg in "$@"; do
                case "$arg" in
                    -S|--|"") continue ;;
                    *) print -r -- "$arg" ;;
                esac
            done
        }

        source "$CDC_PROJECT_ROOT/cdc.plugin.zsh"

        words=(cdc -P "")
        CURRENT=3
        _cdc
    '

    assert_success
    assert_output_contains "one"
    assert_output_contains "two"
    assert_output_contains "three"
    assert_output_not_contains "repo"
    assert_output_not_contains "plain"
    assert_output_not_contains "custom"
}

@test "zsh completion suppresses directory operands after action flags" {
    export CDC_PROJECT_ROOT

    run zsh -c '
        compdef() { :; }
        compadd() {
            local arg
            for arg in "$@"; do
                case "$arg" in
                    -S|--|"") continue ;;
                    *) print -r -- "$arg" ;;
                esac
            done
        }

        source "$CDC_PROJECT_ROOT/cdc.plugin.zsh"

        words=(cdc -p "")
        CURRENT=3
        _cdc
    '

    assert_success
    [ "$output" = "" ]
}

@test "zsh option completion display includes flags and corrected descriptions" {
    export CDC_PROJECT_ROOT

    run zsh -c '
        compdef() { :; }
        compadd() {
            local display_array

            while (( $# )); do
                case "$1" in
                    -d)
                        display_array="$2"
                        shift 2
                        ;;
                    --)
                        shift
                        break
                        ;;
                    *)
                        shift
                        ;;
                esac
            done

            eval "print -rl -- \"\${${display_array}[@]}\""
        }

        source "$CDC_PROJECT_ROOT/cdc.plugin.zsh"

        words=(cdc -)
        CURRENT=2
        _cdc
    '

    assert_success
    assert_output_contains "-P  cd to a configured parent directory"
    assert_output_contains "-R  cd to any directory, even if it is not a repository"
    assert_output_contains "-p  cd to the previous directory and pop it from the stack"
    assert_output_not_contains "even it is not"
}

@test "zsh can change directories and pop history" {
    export CDC_PROJECT_ROOT
    export CDC_FIXTURE

    run zsh -c '
        source "$CDC_PROJECT_ROOT/cdc.sh"
        cd "$CDC_FIXTURE/start"
        export CDC_DIRS="$CDC_FIXTURE/one:$CDC_FIXTURE/two:$CDC_FIXTURE/three"
        export CDC_IGNORE=ignored
        export CDC_REPOS_ONLY=false

        cdc repo || exit 1
        [[ "$PWD" == "$CDC_FIXTURE/one/repo" ]] || exit 2

        cdc plain || exit 3
        [[ "$PWD" == "$CDC_FIXTURE/two/plain" ]] || exit 4

        cdc -p || exit 5
        [[ "$PWD" == "$CDC_FIXTURE/one/repo" ]] || exit 6
        [[ ${#CDC_HISTORY[@]} -eq 1 ]] || exit 7
    '

    assert_success
}

@test "zsh honors repo-only and subdirectory behavior" {
    export CDC_PROJECT_ROOT
    export CDC_FIXTURE

    run zsh -c '
        source "$CDC_PROJECT_ROOT/cdc.sh"
        cd "$CDC_FIXTURE/start"
        export CDC_DIRS="$CDC_FIXTURE/one:$CDC_FIXTURE/two:$CDC_FIXTURE/three"
        export CDC_IGNORE=ignored
        export CDC_REPOS_ONLY=true

        cdc -w plain >"$CDC_FIXTURE/zsh-plain-missing.out" && exit 1
        [[ $? -eq 2 ]] || exit 2

        cdc -R -w plain >"$CDC_FIXTURE/zsh-plain.out" || exit 3
        [[ "$(cat "$CDC_FIXTURE/zsh-plain.out")" == "$CDC_FIXTURE/two/plain" ]] || exit 4

        cdc repo/bin || exit 5
        [[ "$PWD" == "$CDC_FIXTURE/one/repo/bin" ]] || exit 6
        [[ ${CDC_HISTORY[-1]} == "$CDC_FIXTURE/one/repo" ]] || exit 7
    '

    assert_success
}
