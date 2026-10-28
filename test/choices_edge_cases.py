"""Check collision failures, filtering, and terminal gating in both shells."""
import os
import pty
import select
import subprocess
import time

fixture = os.environ['CDC_FIXTURE']


def terminal_run(shell, script, answers=(), stdin_terminal=True, stdout_terminal=True):
    """Run with independently controlled terminal descriptors and prompt replies."""
    master, slave = pty.openpty()
    process = subprocess.Popen(
        [shell, '-c', 'source "$CDC_PROJECT_ROOT/cdc.sh"\n' + script],
        stdin=slave if stdin_terminal else subprocess.PIPE,
        stdout=slave if stdout_terminal else subprocess.PIPE,
        stderr=slave,
    )
    os.close(slave)
    if not stdin_terminal:
        process.stdin.close()
    replies = iter(answers)
    output = b''
    pending = b''
    deadline = time.monotonic() + 10
    try:
        while time.monotonic() < deadline:
            if select.select([master], [], [], .1)[0]:
                try:
                    data = os.read(master, 65536)
                except OSError:
                    break
                if not data:
                    break
                output += data
                pending += data
                if ((b'Choose a directory' in pending and pending.endswith(b': '))
                        or (b'Save this as your default' in pending
                            and pending.endswith(b'[y/N] '))):
                    os.write(master, next(replies))
                    pending = b''
            elif process.poll() is not None:
                break
        if process.poll() is None:
            process.wait(timeout=2)
        if not stdout_terminal:
            output += process.stdout.read()
        assert process.returncode == 0, (shell, script, output.decode())
        return output
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
        os.close(master)


for shell in ('bash', 'zsh'):
    base = fixture + '/edges-' + shell
    for parent in ('one', 'two', 'three'):
        os.makedirs(base + '/' + parent + '/repo/.git', exist_ok=True)
    prefix = '''
export CDC_DIRS="{base}/one:{base}/two:{base}/three"
export CDC_CHOICES_FILE="{base}/choices"
export CDC_COLLISION_MODE=cache
cd "$CDC_FIXTURE/start" || exit 99
'''.format(base=base)
    # Deleting a cached directory must reprompt while other collisions remain.
    output = terminal_run(shell, prefix + '''
printf 'repo\\trepo\\t%s\\n' "${CDC_DIRS%%:*}/repo" > "$CDC_CHOICES_FILE"
rm -rf "${CDC_DIRS%%:*}/repo"
cdc repo || exit 1
[[ $PWD == "${CDC_DIRS##*:}/repo" ]] || exit 2
''', (b'2\n',))
    assert b'Multiple matches' in output

    # Both ignore rules and repository requirements invalidate an existing choice.
    for rule in ('ignore', 'repo-only'):
        os.makedirs(base + '/one/repo/.git', exist_ok=True)
        rule_script = ('export CDC_IGNORE="${CDC_DIRS##*:}/repo"' if rule == 'ignore'
                       else 'rmdir "${CDC_DIRS##*:}/repo/.git"\nexport CDC_REPOS_ONLY=true')
        output = terminal_run(shell, prefix + '''
printf 'repo\\trepo\\t%s\\n' "${CDC_DIRS##*:}/repo" > "$CDC_CHOICES_FILE"
''' + rule_script + '''
cdc repo || exit 1
[[ $PWD == "${CDC_DIRS%%:*}/repo" ]] || exit 2
''', (b'1\n',))
        assert b'Multiple matches' in output

    output = terminal_run(shell, prefix + '''
rm -f "$CDC_CHOICES_FILE"
CDC_CURRENT=unchanged
cdc repo
result=$?
[[ $result == 130 && $PWD == "$CDC_FIXTURE/start" ]] || exit 1
[[ ${#CDC_HISTORY[@]} == 0 && $CDC_CURRENT == unchanged ]] || exit 2
[[ ! -e $CDC_CHOICES_FILE ]] || exit 3
''', (b'\x04',))
    assert b'Selection canceled' in output and b'not found' not in output

    # A file as cache parent fails predictably, including when tests run as root.
    output = terminal_run(shell, prefix + '''
export CDC_CHOICES_FILE="$CDC_CHOICES_FILE/blocked"
cdc repo || exit 1
[[ $PWD == "${CDC_DIRS%%:*}/repo" ]] || exit 2
'''.replace('export CDC_CHOICES_FILE=', 'touch "$CDC_CHOICES_FILE"\nexport CDC_CHOICES_FILE='), (b'1\n',))
    assert b'Unable to save collision choice' in output

    for stdin_terminal, stdout_terminal in ((False, True), (True, False)):
        output = terminal_run(shell, prefix + '''
rm -f "$CDC_CHOICES_FILE"
cdc repo || exit 1
[[ $PWD == "${CDC_DIRS%%:*}/repo" ]] || exit 2
[[ ! -e $CDC_CHOICES_FILE ]] || exit 3
''', stdin_terminal=stdin_terminal, stdout_terminal=stdout_terminal)
        assert b'Multiple matches' not in output

    # Forced selection works identically for repositories and parent directories.
    for mode, flags, name in (('repo', '-s', 'repo'), ('parent', '-sP', 'parents')):
        for parent in ('one', 'two'):
            os.makedirs(base + '/' + parent + '/' + name + '/bin', exist_ok=True)
        settings = prefix + 'export CDC_DIRS="{base}/one:{base}/two"\n'.format(base=base)
        if mode == 'parent':
            settings += 'export CDC_DIRS="{base}/one/parents:{base}/two/parents"\n'.format(base=base)
        seed = "printf '%s\\t%s\\t%s\\n' " + mode + ' ' + name + ' "' + base + '/one/' + name + '" > "$CDC_CHOICES_FILE"\n'
        first = base + '/one/' + name
        second = base + '/two/' + name
        navigate = 'cdc ' + flags + ' ' + name + '/bin || exit 1\n'
        check_second = '[[ $PWD == "' + second + '/bin" ]] || exit 2\n'
        # Enter and n preserve the old default; y replaces it.
        for answer, expected in ((b'\n', first), (b'n\n', first), (b'y\n', second),
                                 (b'\x04', first)):
            normal = 'cdc ' + ('-P ' if mode == 'parent' else '') + name + ' || exit 3\n'
            check_default = '[[ $PWD == "' + expected + '" ]] || exit 4\n'
            output = terminal_run(shell, settings + seed + navigate + check_second +
                                  normal + check_default, (b'2\n', answer))
            assert output.count(b'Save this as your default') == 1, output
            with open(base + '/choices') as saved:
                assert saved.read() == mode + '\t' + name + '\t' + expected + '\n'
        output = terminal_run(shell, settings + seed + navigate + check_second,
                              (b'2\n', b'invalid\n', b'yes\n'))
        assert b'Enter y or n.' in output
        with open(base + '/choices') as saved:
            assert saved.read() == mode + '\t' + name + '\t' + second + '\n'
        # Choosing the existing default skips confirmation and leaves it alone.
        output = terminal_run(shell, settings + seed + 'cdc ' + flags + ' ' + name,
                              (b'1\n',))
        assert b'Save this as your default' not in output
        # No previous preference: a temporary visit must not create one.
        output = terminal_run(shell, settings + 'rm -f "$CDC_CHOICES_FILE"\n' +
                              navigate + check_second, (b'2\n', b'\n'))
        assert not os.path.exists(base + '/choices')
        # A unique candidate resolves without either prompt or cache creation.
        unique = ('export CDC_DIRS="' + base + '/one' +
                  ('/parents' if mode == 'parent' else '') + '"\n')
        output = terminal_run(shell, settings + unique + 'cdc ' + flags + ' ' + name)
        assert b'Multiple matches' not in output and b'Save this as your default' not in output
        assert not os.path.exists(base + '/choices')
        # EOF cancels forced selection, preserving the prior preference.
        output = terminal_run(shell, settings + seed + 'cdc ' + flags + ' ' + name +
                              '\n[[ $? == 130 ]] || exit 1\n', (b'\x04',))
        assert b'Selection canceled' in output
        # Neither one-terminal case may prompt or replace the saved preference.
        for stdin_terminal, stdout_terminal in ((False, True), (True, False)):
            output = terminal_run(shell, settings + seed + navigate +
                                  '[[ $PWD == "' + first + '/bin" ]] || exit 2',
                                  stdin_terminal=stdin_terminal, stdout_terminal=stdout_terminal)
            assert b'Multiple matches' not in output and b'Save this as your default' not in output
            with open(base + '/choices') as saved:
                assert saved.read() == mode + '\t' + name + '\t' + first + '\n'

    # Policy behavior and -s overrides must agree for repo and parent collisions.
    for kind, flag, name in (('repo', '', 'repo'), ('parent', '-P ', 'parents')):
        first = base + '/one/' + name
        second = base + '/two/' + name
        for directory in (first, second):
            os.makedirs(directory + '/bin', exist_ok=True)
        settings = prefix + 'export CDC_DIRS="' + base + '/one:' + base + '/two"\n'
        if kind == 'parent':
            settings += 'export CDC_DIRS="' + first + ':' + second + '"\n'
        seed = "printf '%s\\t%s\\t%s\\n' " + kind + ' ' + name + ' "' + second + '" > "$CDC_CHOICES_FILE"\n'
        lookup = 'cdc ' + flag + name + '/bin || exit 1\n'
        for policy in ('unset', '', 'first', 'cache', 'prompt', 'invalid'):
            config = ('unset CDC_COLLISION_MODE\n' if policy == 'unset' else
                      'export CDC_COLLISION_MODE="' + policy + '"\n')
            expected = second if policy == 'cache' else first
            # Prompt twice without touching the existing record.
            replies = (b'1\n', b'1\n') if policy == 'prompt' else ()
            script = settings + config + seed + (lookup +
                     '[[ $PWD == "' + expected + '/bin" ]] || exit 2\n') * 2
            output = terminal_run(shell, script, replies)
            assert output.count(b'Multiple matches') == (2 if policy == 'prompt' else 0)
            assert b'Save this as your default' not in output
            assert (b'Invalid CDC_COLLISION_MODE' in output) == (policy == 'invalid')
            with open(base + '/choices') as saved:
                assert saved.read() == kind + '\t' + name + '\t' + second + '\n'

        output = terminal_run(shell, settings + 'unset CDC_COLLISION_MODE\n' +
                              'rm -f "$CDC_CHOICES_FILE"\n' + lookup +
                              '[[ $PWD == "' + first + '/bin" ]] || exit 2')
        assert b'Multiple matches' not in output
        assert not os.path.exists(base + '/choices')

        for policy in ('first', 'cache', 'prompt'):
            config = 'export CDC_COLLISION_MODE=' + policy + '\n'
            forced = 'cdc -s ' + flag + name + '/bin || exit 1\n'
            if policy == 'cache':
                for answer, expected_record in ((b'\n', second), (b'y\n', first)):
                    output = terminal_run(shell, settings + config + seed + forced +
                                          '[[ $PWD == "' + first + '/bin" ]] || exit 2',
                                          (b'1\n', answer))
                    assert output.count(b'Save this as your default') == 1
                    with open(base + '/choices') as saved:
                        assert saved.read() == kind + '\t' + name + '\t' + expected_record + '\n'
            else:
                # Instrument the cache boundary to catch reads as well as writes.
                no_cache = """
_cdc_cached_choice() { printf 'unexpected cache read\\n' >&2; return 1; }
_cdc_save_choice() { printf 'unexpected cache write\\n' >&2; return 1; }
"""
                for existing in (True, False):
                    prepare = seed if existing else 'rm -f "$CDC_CHOICES_FILE"\n'
                    output = terminal_run(shell, settings + config + prepare + no_cache +
                                          forced + '[[ $PWD == "' + first + '/bin" ]] || exit 2',
                                          (b'1\n',))
                    assert b'Save this as your default' not in output
                    assert b'Saved choices are used when' not in output
                    assert b'unexpected cache' not in output
                    if existing:
                        with open(base + '/choices') as saved:
                            assert saved.read() == kind + '\t' + name + '\t' + second + '\n'
                    else:
                        assert not os.path.exists(base + '/choices')
            # Prompt mode with no prior cache never creates one.
            if policy == 'prompt':
                terminal_run(shell, settings + config + 'rm -f "$CDC_CHOICES_FILE"\n' +
                             lookup, (b'2\n',))
                assert not os.path.exists(base + '/choices')
            # Redirection defeats prompting even for cache/prompt policies.
            for stdin_terminal, stdout_terminal in ((False, True), (True, False)):
                output = terminal_run(shell, settings + config + seed + lookup +
                                      '[[ $PWD == "' + first + '/bin" ]] || exit 2',
                                      stdin_terminal=stdin_terminal, stdout_terminal=stdout_terminal)
                assert b'Multiple matches' not in output
                with open(base + '/choices') as saved:
                    assert saved.read() == kind + '\t' + name + '\t' + second + '\n'
