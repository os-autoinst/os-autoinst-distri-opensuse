# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
"""Functional tests for sysstat.

Ported from tests/console/sysstat.pm. Exercises the sysstat service and the
pidstat, iostat, mpstat and sar tools and validates the generated reports.

The test runs standalone on a booted SUT and does not depend on openQA
variables; it derives the expected layout from the running system. The
independent samplers and sa1 run in parallel and sa1 collects with a short
interval, which keeps the same commands and assertions but cuts the runtime.
"""

import glob
import os
import re
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor

import pytest

os.environ['S_COLORS'] = 'never'
os.environ['LC_TIME'] = 'C'


def run(cmd):
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)


def run_shell(cmd):
    return run(['bash', '-c', cmd])


def output(cmd):
    result = run(cmd)
    assert result.returncode == 0, f"{' '.join(cmd)} failed: {result.stderr.strip()}"
    return result.stdout


def find_sa1():
    candidates = sorted(glob.glob('/usr/lib*/sa/sa1'))
    assert candidates, 'sa1 is not installed'
    return candidates[0]


@pytest.fixture(scope='session')
def sysstat():
    run_shell('rm -rf /var/log/sa/sa*')
    assert run(['systemctl', 'start', 'sysstat.service']).returncode == 0, 'cannot start sysstat.service'

    # Capture the day before sa1 runs: samples written across midnight land in
    # the previous day's file.
    day_long = time.strftime('%Y%m%d')
    day_short = time.strftime('%d')

    # The samplers are independent from each other and from sa1, so run them
    # together instead of one after another.
    commands = {
        'sa1': [find_sa1(), '1', '5'],
        'pidstat': ['pidstat', '2', '5'],
        'iostat': ['iostat', '2', '5'],
        'mpstat': ['mpstat', '-P', 'ALL', '2', '5'],
    }
    with ThreadPoolExecutor(max_workers=len(commands)) as pool:
        results = {name: pool.submit(run, cmd) for name, cmd in commands.items()}
        results = {name: future.result() for name, future in results.items()}
    for name, result in results.items():
        assert result.returncode == 0, f'{name} failed: {result.stderr.strip()}'

    candidates = ['/var/log/sa/sa' + day_long, '/var/log/sa/sa' + day_short]
    path = next((candidate for candidate in candidates if os.path.exists(candidate)), None)
    assert path, f'no activity file found in {candidates}'

    yield {'sa_file': path, **{name: result.stdout for name, result in results.items()}}
    run(['systemctl', 'stop', 'sysstat.service'])


def test_service_lifecycle(sysstat):
    for action in ('stop', 'start', 'restart'):
        assert run(['systemctl', action, 'sysstat.service']).returncode == 0, f'{action} failed'
    assert output(['systemctl', 'is-active', 'sysstat.service']).strip() == 'active'


def test_sa_file(sysstat):
    assert os.path.getsize(sysstat['sa_file']) > 0


def test_pidstat_uses_24h_time():
    # With LC_TIME=C the first column is HH:MM:SS followed by the numeric UID,
    # so PID keeps its position; a 12h clock inserts an AM/PM column instead.
    lines = output(['pidstat']).splitlines()
    samples = [line for line in lines if re.match(r'^\d{2}:\d{2}:\d{2}\s', line) and line.split()[1].isdigit()]
    assert samples, 'no pidstat sample line with a 24h timestamp and a numeric UID, check LC_TIME'
    fields = samples[0].split()
    assert re.match(r'^\d{2}:\d{2}:\d{2}$', fields[0])
    assert fields[2].isdigit(), 'PID is not the column after the UID'


def test_pidstat_samples(sysstat):
    # five iterations plus the header
    assert sum('UID' in line for line in sysstat['pidstat'].splitlines()) == 6


def test_iostat_samples(sysstat):
    assert sum('Device' in line for line in sysstat['iostat'].splitlines()) == 5


def test_mpstat_samples(sysstat):
    # five iterations plus the average, and an initial snapshot on newer versions
    assert sum('all' in line for line in sysstat['mpstat'].splitlines()) in (6, 7)


def test_pidstat_header():
    assert re.search(r'UID\s+PID\s+%usr\s+%system\s+%guest\s+(?:%wait\s+)?%CPU\s+CPU\s+Command', output(['pidstat']))


def test_iostat_header():
    assert re.search(r'avg-cpu:\s+%user\s+%nice\s+%system\s+%iowait\s+%steal\s+%idle', output(['iostat']))


def test_mpstat_header():
    assert re.search(r'CPU\s+%usr\s+%nice\s+%sys\s+%iowait\s+%irq\s+%soft\s+%steal\s+%guest\s+%gnice\s+%idle', output(['mpstat']))


def test_sar_cpu(sysstat):
    text = output(['sar', '-u', '-f', sysstat['sa_file']])
    assert re.search(r'CPU\s+%user\s+%nice\s+%system\s+%iowait\s+%steal\s+%idle', text)


def test_sar_network(sysstat):
    text = output(['sar', '-n', 'DEV', '-f', sysstat['sa_file']])
    assert re.search(r'IFACE\s+rxpck/s\s+txpck/s\s+rxkB/s\s+txkB/s\s+rxcmp/s\s+txcmp/s\s+rxmcst/s\s+%ifutil', text)


def test_sar_memory(sysstat):
    text = output(['sar', '-r', '-f', sysstat['sa_file']])
    assert re.search(r'kbmemfree\s+(?:kbavail\s+)?kbmemused\s+%memused\s+kbbuffers\s+kbcached\s+kbcommit\s+%commit\s+kbactive\s+kbinact\s+kbdirty', text)


def test_sar_io(sysstat):
    text = output(['sar', '-b', '-f', sysstat['sa_file']])
    assert re.search(r'tps\s+rtps\s+wtps\s+(?:dtps\s+)?bread/s\s+bwrtn/s(?:\s+bdscd/s)?', text)


def test_sar_paging(sysstat):
    text = output(['sar', '-B', '-f', sysstat['sa_file']])
    assert re.search(r'pgpgin/s\s+pgpgout/s\s+fault/s\s+majflt/s\s+pgfree/s\s+pgscank/s\s+pgscand/s\s+pgsteal/s\s+(?:pgprom/s\s+pgdem/s|%vmeff)', text)


def test_sar_hugepages(sysstat):
    text = output(['sar', '-H', '-f', sysstat['sa_file']])
    assert re.search(r'kbhugfree\s+kbhugused\s+%hugused', text)


def test_sar_swap(sysstat):
    text = output(['sar', '-S', '-f', sysstat['sa_file']])
    assert re.search(r'kbswpfree\s+kbswpused\s+%swpused\s+kbswpcad\s+%swpcad', text)
