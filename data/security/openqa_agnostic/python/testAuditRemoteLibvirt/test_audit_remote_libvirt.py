# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

import os
import platform
import re
import subprocess
import sys
import warnings
from collections import OrderedDict

import pytest

AUDIT_TEST_DIR = os.environ.get('AUDIT_TEST_DIR', '/usr/local/eal4_testing')
SUITE_DIR = os.path.join(AUDIT_TEST_DIR, 'audit-test')
CASE_DIR = os.path.join(SUITE_DIR, 'audit-remote-libvirt')
IMAGE_DIR = '/var/lib/libvirt/images'
VM_NAME = 'nested-L2-vm'
NETWORK_XML = '/etc/libvirt/qemu/networks/default.xml'
RUN_TIMEOUT = 300
# Placeholder parameter used when no baseline can be read at collection time,
# so the run reports one clear failure instead of collecting zero tests.
NO_BASELINE = 'no-baseline'

# Same pattern as audit_test::parse_lines, e.g. "[3]  remote_libvirt_start   PASS"
_RESULT_RE = re.compile(r'\[(\d+)\]\s+(.*)\s+(PASS|FAIL|ERROR)')


def _run(cmd, **kwargs):
    """Run a command capturing text stdout/stderr.

    'capture_output' and 'text' in subprocess.run are Python 3.7+ only, but SLE 15 ships Python 3.6 as its
    system interpreter, so spell out the equivalent long-hand arguments instead so it works on Python 3.6+.

    :param cmd: (list | str) command to run, a string requires shell=True in kwargs
    :param kwargs: (dict) extra keyword arguments passed through to subprocess.run
    :return: (subprocess.CompletedProcess) finished process with stdout/stderr decoded as text
    """
    kwargs.setdefault('stdout', subprocess.PIPE)
    kwargs.setdefault('stderr', subprocess.PIPE)
    return subprocess.run(cmd, universal_newlines=True, **kwargs)


def _assert_run(cmd):
    """Run a command and fail the test if it exits non-zero.

    :param cmd: (list) command to run
    :return: (subprocess.CompletedProcess) finished process
    """
    result = _run(cmd)
    assert result.returncode == 0, (
        f'"{" ".join(cmd)}" failed with exit code {result.returncode}:\n'
        f'{result.stdout}\n{result.stderr}'
    )
    return result


def _parse_results(text):
    """Parse audit-test result lines into an ordered mapping.

    :param text: (str) run.bash output or baseline_run.log content
    :return: (OrderedDict) test id (str) -> (name (str), result (str)) tuple, in output order
    """
    results = OrderedDict()
    for line in text.splitlines():
        match = _RESULT_RE.search(line)
        if match:
            results[match.group(1)] = (match.group(2).strip(), match.group(3))
    return results


def _baseline_path():
    """Return the baseline file for this architecture, as audit_test::upload_audit_test_logs picks it.

    :return: (str) path to baseline_run.log.<arch> if present, otherwise to baseline_run.log
    """
    arch_specific = os.path.join(CASE_DIR, 'baseline_run.log.' + platform.machine())
    if os.path.isfile(arch_specific):
        return arch_specific
    return os.path.join(CASE_DIR, 'baseline_run.log')


def _load_baseline():
    """Read and parse the baseline results.

    :return: (OrderedDict) parsed baseline, empty if the file is missing or has no result lines
    """
    try:
        with open(_baseline_path()) as handle:
            return _parse_results(handle.read())
    except (IOError, OSError):
        return OrderedDict()


def pytest_generate_tests(metafunc):
    """Create one test case per baseline entry, so each audit-test result shows up on its own.

    :param metafunc: (pytest.Metafunc) collection context of the test function
    """
    if 'case_id' not in metafunc.fixturenames:
        return
    baseline = _load_baseline()
    if not baseline:
        metafunc.parametrize('case_id', [NO_BASELINE])
        return
    metafunc.parametrize(
        'case_id',
        list(baseline),
        ids=[f'{case_id}-{name}' for case_id, (name, _) in baseline.items()],
    )


@pytest.fixture(scope='session', autouse=True)
def log_environment_info(record_testsuite_property):
    """Print version and environment details to stdout so they are visible in the serial terminal.

    The same values are recorded as testsuite <properties> in results.xml.

    :param record_testsuite_property: (callable) pytest fixture recording a testsuite property in results.xml
    """
    libvirt_ver = _run(['rpm', '-q', 'libvirt-daemon']).stdout.strip()
    print(
        f'\n--- Environment ---\n'
        f'libvirt-daemon:  {libvirt_ver}\n'
        f'audit-test:      {SUITE_DIR}\n'
        f'baseline:        {_baseline_path()}\n'
        f'Python:          {sys.version}\n'
        f'pytest:          {pytest.__version__}\n'
        f'-------------------',
        file=sys.stdout,
    )
    record_testsuite_property('libvirt_daemon_version', libvirt_ver)
    record_testsuite_property('python_version', sys.version.split()[0])
    record_testsuite_property('pytest_version', pytest.__version__)


@pytest.fixture(scope='session')
def baseline():
    """Return the parsed baseline results.

    :return: (OrderedDict) test id (str) -> (name (str), result (str)) tuple
    """
    return _load_baseline()


@pytest.fixture(scope='session')
def virt_binary():
    """Return the libvirt daemon the suite has to audit.

    SLE 15-SP5+ runs the modular virtqemud, older releases the monolithic libvirtd.

    :return: (str) 'virtqemud' or 'libvirtd', whichever is active
    """
    for daemon in ('virtqemud', 'libvirtd'):
        if _run(['systemctl', 'is-active', '--quiet', daemon]).returncode == 0:
            return daemon
    pytest.fail('neither virtqemud nor libvirtd is active, libvirt must be running')


@pytest.fixture(scope='session')
def default_network():
    """Make sure the libvirt 'default' network is defined and active, undoing any change afterwards.

    :return: (str) name of the network
    """
    defined = started = False
    if _run(['virsh', 'net-info', 'default']).returncode != 0:
        _assert_run(['virsh', 'net-define', NETWORK_XML])
        defined = True
    if not re.search(r'^Active:\s+yes', _run(['virsh', 'net-info', 'default']).stdout, re.M):
        _assert_run(['virsh', 'net-start', 'default'])
        started = True
    yield 'default'
    if started:
        _run(['virsh', 'net-destroy', 'default'])
    if defined:
        _run(['virsh', 'net-undefine', 'default'])


@pytest.fixture(scope='session')
def guest(default_network):
    """Define and start the nested L2 guest that acts as the "remote" VM, removing it afterwards.

    :param default_network: (str) name of the active libvirt network the guest attaches to
    :return: (str) libvirt domain name of the guest
    """
    image = os.path.join(IMAGE_DIR, VM_NAME + '.qcow2')
    assert os.path.isfile(image), f'guest disk image {image} is missing'
    _assert_run(['virsh', 'define', os.path.join(IMAGE_DIR, VM_NAME + '.xml')])
    try:
        _assert_run(['virsh', 'start', VM_NAME])
        yield VM_NAME
    finally:
        _run(['virsh', 'destroy', VM_NAME])
        _run(['virsh', 'undefine', VM_NAME])


@pytest.fixture(scope='session')
def run_results(guest, virt_binary):
    """Run audit-remote-libvirt/run.bash once and parse its results.

    The output is also saved to run.log in the current directory for upload.

    :param guest: (str) libvirt domain name of the running guest
    :param virt_binary: (str) libvirt daemon binary the suite audits
    :return: (OrderedDict) test id (str) -> (name (str), result (str)) tuple
    """
    assert os.path.isfile(os.path.join(CASE_DIR, 'run.bash')), f'audit-test suite not found in {SUITE_DIR}'

    env = os.environ.copy()
    # A stale ARCH would make the suite load cases for another architecture.
    env.pop('ARCH', None)
    env['MODE'] = os.environ.get('AUDIT_TEST_MODE', '64')
    env['VIRT_BINARY'] = virt_binary
    env['AUDIT_TEST_REMOTE_VM'] = guest
    env['AUGROK'] = os.path.join(SUITE_DIR, 'utils', 'augrok')

    try:
        result = _run(['./run.bash'], cwd=CASE_DIR, env=env, stderr=subprocess.STDOUT, timeout=RUN_TIMEOUT)
        output = result.stdout
        print(f'\nrun.bash exited with {result.returncode}')
    except subprocess.TimeoutExpired as exc:
        output = exc.output or ''
        print(f'\nrun.bash timed out after {RUN_TIMEOUT}s')

    with open('run.log', 'w') as handle:
        handle.write(output)
    print(f'--- run.bash output ---\n{output}\n-----------------------')
    return _parse_results(output)


def _softfail(record_property, message):
    """Report a result that is better than the baseline without failing the test.

    openQA shows these as softfails; JUnit has no such state, so the message goes into a
    'softfail' testcase property and a pytest warning instead.

    :param record_property: (callable) pytest fixture recording a testcase property in results.xml
    :param message: (str) description of the difference from the baseline
    """
    record_property('softfail', message)
    warnings.warn(message)
    print(f'SOFTFAIL: {message}')


def test_result_matches_baseline(case_id, baseline, run_results, record_property):
    """Check that one audit-test result matches its baseline entry.

    A PASS where the baseline has FAIL/ERROR is a softfail, any other difference fails.

    :param case_id: (str) audit-test case id from the baseline
    :param baseline: (OrderedDict) parsed baseline results
    :param run_results: (OrderedDict) parsed results of the current run
    :param record_property: (callable) pytest fixture recording a testcase property in results.xml
    """
    if case_id == NO_BASELINE:
        pytest.fail(f'no results could be read from {_baseline_path()}')
    b_name, b_result = baseline[case_id]
    assert case_id in run_results, f'[{case_id}] {b_name}: no result in the current run (baseline: {b_result})'

    name, result = run_results[case_id]
    message = (
        f'Current:  [{case_id}] {name} {result}\n'
        f'Baseline: [{case_id}] {b_name} {b_result}'
    )
    if result == b_result:
        print(f'[{case_id}] {name} {result}, same as baseline')
    elif result == 'PASS':
        _softfail(record_property, 'Test result is NOT same as baseline\n' + message)
    else:
        pytest.fail('Test result is NOT same as baseline\n' + message)


def test_no_unbaselined_failures(baseline, run_results, record_property):
    """Check results that have no baseline entry.

    A PASS without baseline is a softfail (poo#93441), a FAIL/ERROR fails.

    :param baseline: (OrderedDict) parsed baseline results
    :param run_results: (OrderedDict) parsed results of the current run
    :param record_property: (callable) pytest fixture recording a testcase property in results.xml
    """
    failures = []
    for case_id, (name, result) in run_results.items():
        if case_id in baseline:
            continue
        message = f'No baseline found (defined): [{case_id}] {name} {result}'
        if result == 'PASS':
            _softfail(record_property, message)
        else:
            failures.append(message)
    assert not failures, '\n'.join(failures)
