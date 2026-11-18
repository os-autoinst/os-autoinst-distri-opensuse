# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

import re
import shlex
import subprocess
import sys

import pytest

SUITE = 'libsoup-3.0'

# /logger/long-invalid-body-length keeps a 2 GiB server body and a 2 GiB
# logged copy in memory at once (about 4.2 GB RSS). Below this much RAM
# plus swap the kernel OOM-kills it and openQA fails the module on the
# OOM message, so the case is skipped there and the rest of logger-test
# still runs.
LOGGER_TEST = f'{SUITE}/logger-test.test'
LOGGER_BIG_CASE = '/logger/long-invalid-body-length'
LOGGER_BIG_MIN_KIB = 5 * 1024 * 1024


def _get_test_list():
    """Discover available test cases from gnome-desktop-testing-runner."""
    result = subprocess.run(
        ['gnome-desktop-testing-runner', '--list', SUITE],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
    )
    if result.returncode != 0:
        pytest.fail(f'gnome-desktop-testing-runner --list {SUITE} failed (rc={result.returncode}): {result.stderr}')
    tests = {}
    for line in result.stdout.strip().splitlines():
        # Lines: "libsoup-3.0/forms-test.test (/usr/share/installed-tests)"
        m = re.match(r'^(\S+)\s+\((.+)\)$', line.strip())
        if m:
            tests[m.group(1)] = m.group(2)
    return tests


def _memory_kib():
    """Return MemTotal + SwapTotal from /proc/meminfo in KiB."""
    info = {}
    with open('/proc/meminfo') as f:
        for line in f:
            key, value = line.split(':', 1)
            info[key] = int(value.split()[0])
    return info['MemTotal'] + info.get('SwapTotal', 0)


def _exec_line(test_name, test_dir):
    """Return the Exec= command of an installed .test file as a list."""
    with open(f'{test_dir}/{test_name}') as f:
        for line in f:
            if line.startswith('Exec='):
                return shlex.split(line[len('Exec='):].strip())
    pytest.fail(f'no Exec= line in {test_dir}/{test_name}')


_TESTS = _get_test_list()
_SKIP_LOGGER_BIG = LOGGER_TEST in _TESTS and _memory_kib() < LOGGER_BIG_MIN_KIB


def _run_logger_without_big_case():
    """Run logger-test directly, skipping the 4 GiB case."""
    cmd = _exec_line(LOGGER_TEST, _TESTS[LOGGER_TEST]) + ['-s', LOGGER_BIG_CASE]
    result = subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        universal_newlines=True,
        timeout=300,
    )
    print(result.stdout, file=sys.stdout)
    return result.returncode == 0


@pytest.fixture(scope='session')
def suite_results():
    """Run the full test suite once and return per-test pass/fail map."""
    cmd = ['gnome-desktop-testing-runner', '--tap', '-t', '300']
    if _SKIP_LOGGER_BIG:
        # Positional arguments are name prefixes; list every test but
        # logger-test, which runs separately below.
        cmd += [t for t in _TESTS if t != LOGGER_TEST]
    else:
        cmd.append(SUITE)
    result = subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        universal_newlines=True,
    )
    print(result.stdout, file=sys.stdout)

    results = {}
    for line in result.stdout.splitlines():
        m = re.match(r'^(ok|not ok) - (.+)$', line)
        if m:
            results[m.group(2).strip()] = (m.group(1) == 'ok')

    summary = re.search(
        r'# SUMMARY: total=(\d+); passed=(\d+); skipped=(\d+); failed=(\d+)',
        result.stdout,
    )
    if summary:
        print(
            f'\nSuite summary: total={summary.group(1)} '
            f'passed={summary.group(2)} '
            f'skipped={summary.group(3)} '
            f'failed={summary.group(4)}',
            file=sys.stdout,
        )

    if _SKIP_LOGGER_BIG:
        results[LOGGER_TEST] = _run_logger_without_big_case()

    return results


@pytest.mark.parametrize('test_name', list(_TESTS), ids=[t.split('/')[-1] for t in _TESTS])
def test_libsoup(test_name, suite_results):
    """Check that each libsoup installed test passed."""
    if test_name not in suite_results:
        pytest.skip(f'{test_name} not found in runner output')
    assert suite_results[test_name], f'{test_name} failed'


if _SKIP_LOGGER_BIG:

    def test_logger_long_invalid_body_length():
        """Show the skipped 4 GiB logger case in the results."""
        pytest.skip(
            f'{LOGGER_BIG_CASE} needs about 4.2 GB, system has '
            f'{_memory_kib() // 1024} MiB RAM+swap (minimum {LOGGER_BIG_MIN_KIB // 1024} MiB)'
        )
