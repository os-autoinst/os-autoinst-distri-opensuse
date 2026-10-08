# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

import re
import subprocess
import sys
import pytest

_EXPECTED_ALGOS = re.compile(r'p256_mayo2|x25519_frodo640aes|p256_bikel1|rsa3072_falcon512')


def _run(cmd, **kwargs):
    """Run a command capturing text stdout/stderr.

    'capture_output' and 'text' in subprocess.run are Python 3.7+ only, but SLE 15 ships Python 3.6 as its
    system interpreter, so spell out the equivalent long-hand arguments instead so it works on Pyhton 3.6+.

    :param cmd: (list | str) command to run, a string requires shell=True in kwargs
    :param kwargs: (dict) extra keyword arguments passed through to subprocess.run
    :return: (subprocess.CompletedProcess) finished process with stdout/stderr decoded as text
    """
    return subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
        **kwargs
    )


def _required_package_version(package):
    """Return the rpm NEVRA of an installed package, failing the run if it is missing.

    Both packages are a hard prerequisite: the openQA wrapper module installs them and a
    standalone run is expected to have them in place, so absence is an error, not a skip.

    :param package: (str) name of the rpm package to query
    :return: (str) NEVRA of the installed package as printed by 'rpm -q'
    """
    rpm = _run(['rpm', '-q', package])
    assert rpm.returncode == 0, (
        f'"rpm -q {package}" failed with exit code {rpm.returncode}, '
        f'the {package} package must be installed:\n'
        f'{rpm.stdout}\n{rpm.stderr}'
    )
    return rpm.stdout.strip()


@pytest.fixture(scope='session', autouse=True)
def log_environment_info(record_testsuite_property):
    """Print version and environment details to stdout so they are visible in console output,
    eg. they are visible in the serial terminal.

    The same values are recorded as testsuite <properties> in results.xml. Properties are
    written independently of pytest's capture machinery, so they survive the '-s' flag that
    runtest needs in order to stream output to the serial console.

    :param record_testsuite_property: (callable) pytest fixture recording a testsuite property in results.xml
    """
    openssl_ver = _required_package_version('openssl')
    oqs_ver = _required_package_version('oqs-provider')
    print(
        f'\n--- Environment ---\n'
        f'openssl:         {openssl_ver}\n'
        f'oqs-provider:    {oqs_ver}\n'
        f'Python:          {sys.version}\n'
        f'pytest:          {pytest.__version__}\n'
        f'-------------------',
        file=sys.stdout,
    )
    record_testsuite_property('openssl_version', openssl_ver)
    record_testsuite_property('oqs_provider_version', oqs_ver)
    record_testsuite_property('python_version', sys.version.split()[0])
    record_testsuite_property('pytest_version', pytest.__version__)


@pytest.fixture(scope='module')
def matched_algos(record_testsuite_property):
    """Return every expected OQS algorithm found in the openssl provider listing.

    :param record_testsuite_property: (callable) pytest fixture recording a testsuite property in results.xml
    :return: (list[str]) matched algorithm names, deduplicated, in listing order
    """
    result = _run(
        'openssl list -provider oqs -public-key-algorithms | grep oqs',
        shell=True,
    )
    print(
        f'\n--- openssl list -provider oqs -public-key-algorithms | grep oqs ---\n'
        f'{result.stdout}'
        f'--------------------------------------------------------------------',
        file=sys.stdout,
    )
    # dict.fromkeys drops duplicates while keeping the listing order
    found = list(dict.fromkeys(_EXPECTED_ALGOS.findall(result.stdout)))
    record_testsuite_property('oqs_matched_algos', ', '.join(found) if found else 'none')
    record_testsuite_property('oqs_selected_algo', found[0] if found else 'none')
    assert found, (
        f'None of the expected OQS algorithms ({_EXPECTED_ALGOS.pattern}) found.\n'
        f'openssl list output:\n{result.stdout}'
    )
    return found


@pytest.fixture(scope='module')
def algo(matched_algos):
    """Return the first expected OQS algorithm found in the openssl provider listing.

    :param matched_algos: (list[str]) expected OQS algorithms found in the listing
    :return: (str) first matched algorithm name
    """
    return matched_algos[0]


@pytest.fixture(scope='module')
def key_path(algo, tmp_path_factory):
    """Generate an OQS keypair and return its path.

    :param algo: (str) OQS algorithm used to generate the keypair
    :param tmp_path_factory: (pytest.TempPathFactory) pytest fixture creating temporary directories
    :return: (str) path to the generated PEM private key
    """
    path = str(tmp_path_factory.mktemp('oqs') / f'{algo}-key.pem')
    subprocess.run(
        ['openssl', 'genpkey', '-provider', 'oqs', '-algorithm', algo, '-out', path],
        check=True,
    )
    return path


def test_check_expected_algo_is_available(matched_algos, algo):
    """At least one expected OQS algorithm must appear in the openssl provider listing.

    :param matched_algos: (list[str]) expected OQS algorithms found in the listing
    :param algo: (str) algorithm selected for key operations
    """
    print(
        f'Matched expected OQS algorithms ({len(matched_algos)}): {", ".join(matched_algos)}\n'
        f'Selected algorithm for key operations: {algo}',
        file=sys.stdout,
    )
    assert _EXPECTED_ALGOS.match(algo), f'Unexpected algorithm returned by fixture: {algo}'


def test_oqs_algo_sign_verify(algo, key_path, tmp_path_factory):
    """Sign a message with the OQS key and verify the resulting signature.

    :param algo: (str) OQS algorithm of the key
    :param key_path: (str) path to the OQS private key
    :param tmp_path_factory: (pytest.TempPathFactory) pytest fixture creating temporary directories
    """
    workdir = tmp_path_factory.mktemp('oqs_sig')
    test_file = workdir / 'input.txt'
    sig_file = workdir / 'input.sig'

    test_file.write_text('openQA test\n')

    subprocess.run(
        ['openssl', 'pkeyutl', '-sign', '-provider', 'oqs',
         '-inkey', key_path, '-out', str(sig_file), '-in', str(test_file)],
        check=True,
    )

    result = _run(
        ['openssl', 'pkeyutl', '-verify', '-provider', 'oqs',
         '-inkey', key_path, '-sigfile', str(sig_file), '-in', str(test_file)],
    )
    assert result.returncode == 0, (
        f'Signature verification failed for algorithm {algo}:\n{result.stdout}\n{result.stderr}'
    )
    print(f'Signature verification succeeded using algorithm: {algo}', file=sys.stdout)
