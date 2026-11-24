# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

import os
import shutil
import subprocess
import sys
import pytest

PASSPHRASE = 'testpasswd'
PLAINTEXT = 'Hello'

# Cipher -> key size in bytes. These are the defaults mount.ecryptfs offers
# interactively for each cipher, so the mounts match what the original openQA
# module selected by pressing Enter at the "Select key bytes" prompt.
CIPHERS = {
    'aes': 16,
    'blowfish': 16,
    'des3_ede': 24,
    'twofish': 16,
    'cast6': 16,
    'cast5': 16,
}

# Seconds to wait for each mount/umount. A mount completes in about one second;
# keep the sum for all ciphers well below the run_timeout of the openQA wrapper,
# so a hung mount fails one test case instead of the whole run.
CMD_TIMEOUT = 10


def _run(cmd, **kwargs):
    """Run a command capturing text stdout/stderr.

    'capture_output' and 'text' in subprocess.run are Python 3.7+ only, but SLE 15 ships Python 3.6 as its
    system interpreter, so spell out the equivalent long-hand arguments instead so it works on Python 3.6+.

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


def _fips_enabled():
    """Return whether the kernel runs in FIPS mode.

    In FIPS kernel mode eCryptfs cannot allocate its crypto context, so every
    mount is expected to fail with "Operation not permitted".

    :return: (bool) True when /proc/sys/crypto/fips_enabled reads 1
    """
    try:
        with open('/proc/sys/crypto/fips_enabled') as fips:
            return fips.read().strip() == '1'
    except OSError:
        return False


def _fips_kernel_mode_expected():
    """Return whether the caller expects the kernel to run in FIPS mode.

    The openQA wrapper sets ECRYPTFS_EXPECT_FIPS_KERNEL=1 for FIPS kernel mode
    jobs. Then a kernel that does not run in FIPS mode is a failure, not a
    reason to test the normal path. A standalone run does not set the variable,
    and /proc/sys/crypto/fips_enabled alone selects the expected behavior.

    :return: (bool) True when ECRYPTFS_EXPECT_FIPS_KERNEL is 1
    """
    return os.environ.get('ECRYPTFS_EXPECT_FIPS_KERNEL') == '1'


def _ecryptfs_mount_options(mountpoint):
    """Return the mount options of the eCryptfs mount at a given mountpoint.

    :param mountpoint: (str) absolute path of the mountpoint
    :return: (list[str] | None) mount options, or None if nothing of type ecryptfs is mounted there
    """
    with open('/proc/mounts') as mounts:
        for line in mounts:
            fields = line.split()
            if len(fields) >= 4 and fields[1] == mountpoint and fields[2] == 'ecryptfs':
                return fields[3].split(',')
    return None


@pytest.fixture(scope='session', autouse=True)
def log_environment_info(record_testsuite_property):
    """Print version and environment details so they are visible in the console output.

    The same values are recorded as testsuite <properties> in results.xml.

    :param record_testsuite_property: (callable) pytest fixture recording a testsuite property in results.xml
    """
    kernel_ver = os.uname().release
    fips = 'enabled' if _fips_enabled() else 'disabled'
    expected = 'yes' if _fips_kernel_mode_expected() else 'not set'
    print(
        f'\n--- Environment ---\n'
        f'kernel:          {kernel_ver}\n'
        f'FIPS (kernel):   {fips}\n'
        f'FIPS expected:   {expected}\n'
        f'Python:          {sys.version}\n'
        f'pytest:          {pytest.__version__}\n'
        f'-------------------',
        file=sys.stdout,
    )
    record_testsuite_property('kernel_version', kernel_ver)
    record_testsuite_property('fips_kernel_mode', fips)
    record_testsuite_property('fips_kernel_mode_expected', expected)
    record_testsuite_property('python_version', sys.version.split()[0])
    record_testsuite_property('pytest_version', pytest.__version__)


@pytest.fixture(scope='session', autouse=True)
def ecryptfs_module():
    """Load the ecryptfs kernel module and check the filesystem type is registered."""
    result = _run(['modprobe', 'ecryptfs'])
    assert result.returncode == 0, f'modprobe ecryptfs failed:\n{result.stdout}\n{result.stderr}'
    with open('/proc/filesystems') as filesystems:
        assert 'ecryptfs' in filesystems.read().split(), 'ecryptfs is not listed in /proc/filesystems'


@pytest.fixture
def ecryptfs_dirs():
    """Create the lower (encrypted) and upper (mountpoint) directories for one mount.

    They live in the current directory, on the root filesystem, as in the original
    openQA module. Teardown unmounts the upper directory if a failed test left it
    mounted, then removes both directories.

    :return: (tuple[str, str]) absolute paths of the lower and the upper directory
    """
    base = os.path.abspath('ecryptfs_work')
    lower = os.path.join(base, '.private')
    upper = os.path.join(base, 'private')
    os.makedirs(lower)
    os.makedirs(upper)
    yield lower, upper
    if _ecryptfs_mount_options(upper) is not None:
        _run(['umount', '-l', upper], timeout=CMD_TIMEOUT)
    shutil.rmtree(base, ignore_errors=True)


@pytest.mark.parametrize('cipher', list(CIPHERS))
def test_ecryptfs_cipher(cipher, ecryptfs_dirs):
    """Mount an eCryptfs directory with a given cipher and check data is stored encrypted.

    All the answers to mount.ecryptfs's interactive prompts are given as mount
    options. no_sig_cache skips the "never mounted with this key before" warning
    and its yes/no prompts. stdin is /dev/null so an unexpected prompt fails the
    mount instead of hanging it.

    In FIPS kernel mode the mount must fail with "Operation not permitted".
    If the caller expects FIPS kernel mode, the kernel must actually run in it.

    :param cipher: (str) eCryptfs cipher name
    :param ecryptfs_dirs: (tuple[str, str]) lower and upper directory paths
    """
    lower, upper = ecryptfs_dirs
    fips = _fips_enabled()
    if _fips_kernel_mode_expected():
        assert fips, ('FIPS kernel mode is expected (ECRYPTFS_EXPECT_FIPS_KERNEL=1), '
                      'but /proc/sys/crypto/fips_enabled is not 1')
    key_bytes = CIPHERS[cipher]
    options = ','.join([
        f'key=passphrase:passphrase_passwd={PASSPHRASE}',
        f'ecryptfs_cipher={cipher}',
        f'ecryptfs_key_bytes={key_bytes}',
        'ecryptfs_passthrough=n',
        'ecryptfs_enable_filename_crypto=n',
        'no_sig_cache',
    ])
    mount = _run(['mount', '-t', 'ecryptfs', lower, upper, '-o', options],
                 stdin=subprocess.DEVNULL, timeout=CMD_TIMEOUT)
    output = mount.stdout + mount.stderr
    print(f'\n--- mount -t ecryptfs ({cipher}, {key_bytes} bytes) ---\n{output}'
          f'--- exit code: {mount.returncode} ---', file=sys.stdout)

    if fips:
        assert mount.returncode != 0, f'eCryptfs mount with {cipher} succeeded in FIPS kernel mode'
        assert 'Operation not permitted' in output, (
            f'eCryptfs mount with {cipher} failed in FIPS kernel mode for an unexpected reason:\n{output}'
        )
        assert _ecryptfs_mount_options(upper) is None, f'{upper} is mounted despite the failed mount'
        return

    assert mount.returncode == 0, f'eCryptfs mount with {cipher} failed:\n{output}'
    mount_options = _ecryptfs_mount_options(upper)
    assert mount_options is not None, f'no ecryptfs mount on {upper} in /proc/mounts'
    assert f'ecryptfs_cipher={cipher}' in mount_options, (
        f'{upper} is not mounted with cipher {cipher}: {",".join(mount_options)}'
    )
    assert f'ecryptfs_key_bytes={key_bytes}' in mount_options, (
        f'{upper} is not mounted with {key_bytes} key bytes: {",".join(mount_options)}'
    )

    # The file must be readable and writable through the mountpoint
    upper_file = os.path.join(upper, 'testfile')
    with open(upper_file, 'w') as handle:
        handle.write(PLAINTEXT + '\n')
    with open(upper_file) as handle:
        assert PLAINTEXT in handle.read(), f'{upper_file} does not read back "{PLAINTEXT}"'

    # The copy in the lower directory must be ciphertext, not the plain text
    lower_file = os.path.join(lower, 'testfile')
    assert os.path.isfile(lower_file), f'{lower_file} was not created in the lower directory'
    with open(lower_file, 'rb') as handle:
        assert PLAINTEXT.encode() not in handle.read(), f'{lower_file} contains the plain text'

    umount = _run(['umount', '-l', upper], timeout=CMD_TIMEOUT)
    assert umount.returncode == 0, f'umount {upper} failed:\n{umount.stdout}\n{umount.stderr}'
    assert os.listdir(upper) == [], f'{upper} is not empty after umount: {os.listdir(upper)}'
