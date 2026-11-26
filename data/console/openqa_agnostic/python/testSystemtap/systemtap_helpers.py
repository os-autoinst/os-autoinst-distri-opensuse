# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

import glob
import os
import shutil
import subprocess

# A pass-4 build on a slow architecture with kernel debuginfo can take
# several minutes.
STAP_TIMEOUT = 600

PACKAGES = ('systemtap', 'systemtap-runtime', 'systemtap-docs', 'kernel-devel',
            'kernel-default-devel', 'gcc', 'make')

CPU_THROTTLE_FALLBACKS = (
    '/usr/share/doc/packages/systemtap/examples/general/cpu_throttle.stp',
    '/usr/share/systemtap/examples/general/cpu_throttle.stp',
    '/usr/share/systemtap/testsuite/systemtap.examples/general/cpu_throttle.stp',
)


class Result:
    def __init__(self, cmd, returncode, stdout, stderr):
        self.cmd = cmd
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr

    @property
    def output(self):
        return self.stdout + self.stderr

    def describe(self):
        return 'command: {}\nrc: {}\n--- stdout ---\n{}\n--- stderr ---\n{}'.format(
            ' '.join(self.cmd), self.returncode, self.stdout, self.stderr)


def run(cmd, timeout=STAP_TIMEOUT):
    """Run cmd and capture its output; a timeout is reported as rc -1."""
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              universal_newlines=True, timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        return Result(cmd, -1, _text(exc.stdout),
                      _text(exc.stderr) + '\ntimed out after {}s'.format(timeout))
    return Result(cmd, proc.returncode, proc.stdout, proc.stderr)


def _text(data):
    if data is None:
        return ''
    if isinstance(data, bytes):
        return data.decode('utf-8', 'replace')
    return data


def stap(*args, timeout=STAP_TIMEOUT):
    return run(['stap'] + list(args), timeout=timeout)


def which(command):
    return shutil.which(command) is not None


def kernel_release():
    return os.uname().release


def kernel_build_dir():
    return os.path.join('/lib/modules', kernel_release(), 'build')


def has_kernel_build_tree():
    return os.path.isfile(os.path.join(kernel_build_dir(), 'Makefile'))


def kernel_debuginfo_package():
    """Debuginfo package matching the running kernel, or None.

    The running kernel's kbuild tree is owned by its kernel-<flavor>-devel
    package, so the debuginfo package is the same name with -debuginfo-.
    """
    out = run(['rpm', '-qf', os.path.join(kernel_build_dir(), 'Makefile')], timeout=60)
    name = out.stdout.strip().rsplit('.', 1)[0]
    if '-devel-' not in name:
        return None
    return name.replace('-devel-', '-debuginfo-', 1)


def has_kernel_debuginfo():
    package = kernel_debuginfo_package()
    return bool(package) and run(['rpm', '-q', package], timeout=60).returncode == 0


# An EFI-less machine with lockdown enabled makes stap fail before any build,
# because it cannot read the MOK list to sign the module.
SIGNING_ERRORS = ('machine owner keys (MOK)', 'EFI variables are not supported')


def signing_unavailable(result):
    return any(text in result.output for text in SIGNING_ERRORS)


def lockdown_mode():
    """Return the active kernel lockdown mode, or 'none'."""
    try:
        with open('/sys/kernel/security/lockdown') as handle:
            content = handle.read()
    except OSError:
        return 'none'
    for word in content.split():
        if word.startswith('[') and word.endswith(']'):
            return word[1:-1]
    return 'none'


def find_cpu_throttle():
    out = run(['rpm', '-ql', 'systemtap-docs', 'systemtap'], timeout=60).stdout
    for line in out.splitlines():
        if line.endswith('/cpu_throttle.stp') and os.path.isfile(line):
            return line
    for path in CPU_THROTTLE_FALLBACKS:
        if os.path.isfile(path):
            return path
    found = glob.glob('/usr/share/**/cpu_throttle.stp', recursive=True)
    return found[0] if found else None


def versions():
    lines = ['uname -r: {}'.format(kernel_release())]
    for pkg in PACKAGES:
        out = run(['rpm', '-q', pkg], timeout=60)
        lines.append(out.stdout.strip() or out.stderr.strip())
    if which('stap'):
        out = stap('-V', timeout=60)
        lines.append('stap -V: ' + out.output.strip().replace('\n', ' | '))
    lines.append('lockdown: {}'.format(lockdown_mode()))
    return '\n'.join(lines)
