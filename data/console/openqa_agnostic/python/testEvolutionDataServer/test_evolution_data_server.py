# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

import re
import subprocess
import sys

import pytest

SUITE = 'evolution-data-server'


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
    tests = []
    for line in result.stdout.strip().splitlines():
        # Lines: "evolution-data-server/test-vcard.test (/usr/share/installed-tests)"
        name = line.split()[0] if line.strip() else None
        if name:
            tests.append(name)
    return tests


_TESTS = _get_test_list()


@pytest.fixture(scope='session')
def suite_results():
    """Run the full test suite once and return per-test pass/fail map with output."""
    result = subprocess.run(
        ['gnome-desktop-testing-runner', '--tap', '-t', '300', SUITE],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        universal_newlines=True,
    )
    print(result.stdout, file=sys.stdout)

    results = {}
    current_test = None
    current_output = []

    for line in result.stdout.splitlines():
        m_start = re.match(r'^# Running test:\s+(.+)$', line)
        if m_start:
            current_test = m_start.group(1).strip()
            current_output = [line]
            continue

        if current_test:
            current_output.append(line)

        m_end = re.match(r'^(ok|not ok) - (.+)$', line)
        if m_end:
            test_name = m_end.group(2).strip()
            passed = (m_end.group(1) == 'ok')
            results[test_name] = {
                'passed': passed,
                'output': '\n'.join(current_output),
            }

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

    return results


@pytest.mark.parametrize('test_name', _TESTS, ids=[t.split('/')[-1] for t in _TESTS])
def test_evolution_data_server(test_name, suite_results):
    """Check that each evolution-data-server installed test passed."""
    if test_name not in suite_results:
        pytest.skip(f'{test_name} not found in runner output')
    entry = suite_results[test_name]
    assert entry['passed'], f"{test_name} failed:\n{entry['output']}"
