"""Exercise real terminal detection and prompted choices in both shells."""
import os
import pty
import select
import subprocess
import time

fixture = os.environ['CDC_FIXTURE']
for shell in ('bash', 'zsh'):
    cache = fixture + '/' + shell + '-choices'
    os.makedirs(fixture + '/two/repo/bin', exist_ok=True)
    for parent in ('a', 'b', 'c'):
        os.makedirs(fixture + '/' + parent + '/parents', exist_ok=True)
    script = r'''
source "$CDC_PROJECT_ROOT/cdc.sh"
export CDC_CHOICES_FILE="$TEST_CACHE"
export CDC_COLLISION_MODE=cache
cdc MixedCase || exit 12
[[ ! -e $CDC_CHOICES_FILE ]] || exit 13
cdc repo/bin || exit 1
[[ $PWD == "$CDC_FIXTURE/two/repo/bin" ]] || exit 2
cdc repo/bin || exit 3
[[ $PWD == "$CDC_FIXTURE/two/repo/bin" ]] || exit 4
export CDC_DIRS="$CDC_FIXTURE/one:$CDC_FIXTURE/three"
mkdir -p "$CDC_FIXTURE/three/repo"
cdc repo || exit 5
[[ $PWD == "$CDC_FIXTURE/one/repo" ]] || exit 6
export CDC_DIRS="$CDC_FIXTURE/a/parents:$CDC_FIXTURE/b/parents"
cdc -P parents || exit 7
[[ $PWD == "$CDC_FIXTURE/b/parents" ]] || exit 8
cdc -P parents || exit 9
export CDC_DIRS="$CDC_FIXTURE/a/parents:$CDC_FIXTURE/c/parents"
cdc -P parents || exit 10
[[ $PWD == "$CDC_FIXTURE/c/parents" ]] || exit 11
'''
    master, slave = pty.openpty()
    env = dict(os.environ, TEST_CACHE=cache)
    process = subprocess.Popen([shell, '-c', script], stdin=slave,
                               stdout=slave, stderr=slave, env=env)
    os.close(slave)
    output = b''
    answers = iter((b'bad\n', b'2\n', b'1\n', b'2\n', b'2\n'))
    deadline = time.monotonic() + 15
    pending = b''
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
            if b'Choose a directory' in pending:
                os.write(master, next(answers))
                pending = b''
        elif process.poll() is not None:
            break
    if process.poll() is None:
        process.kill()
    os.close(master)
    assert process.wait() == 0, (shell, output.decode())
    with open(cache) as saved:
        records = saved.read().splitlines()
    assert records == ['repo\trepo\t' + fixture + '/one/repo',
                       'parent\tparents\t' + fixture + '/c/parents'], records
    assert output.count(b'Multiple matches') == 4, output.decode()
