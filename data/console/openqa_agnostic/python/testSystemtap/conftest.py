# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

import os

import pytest

import systemtap_helpers as h


class StapEnv:
    def __init__(self):
        self.versions = h.versions()
        self.lockdown = h.lockdown_mode()

    def failure(self, message, result):
        return '{}\n{}\n--- environment ---\n{}'.format(message, result.describe(),
                                                      self.versions)


@pytest.fixture(scope='session')
def stap_env():
    missing = [cmd for cmd in ('stap', 'rpm', 'gcc', 'make') if not h.which(cmd)]
    if missing:
        pytest.skip('missing prerequisites: {}'.format(', '.join(missing)))
    env = StapEnv()
    # The wrapper asserts the same prerequisites before pytest starts; these
    # checks keep a standalone ./runtest from failing with a confusing error.
    if not h.has_kernel_build_tree():
        pytest.skip('no kernel build tree at {}; kernel-default-devel does not '
                    'match the running kernel\n{}'.format(h.kernel_build_dir(),
                                                          env.versions))
    return env


@pytest.fixture(scope='session')
def cpu_throttle(stap_env):
    path = h.find_cpu_throttle()
    if path is None:
        installed = h.run(['rpm', '-q', 'systemtap-docs'], timeout=60).returncode == 0
        message = 'cpu_throttle.stp not found\n{}'.format(stap_env.versions)
        if installed:
            pytest.fail(message)
        pytest.skip(message + '\nsystemtap-docs is not installed')
    return path


@pytest.fixture(scope='session')
def throttle_support(stap_env):
    """therm_throt_process is Intel only; only the architecture may skip it."""
    result = h.stap('-l', 'kprobe.function("therm_throt_process")')
    if result.returncode == 0:
        return result
    if h.signing_unavailable(result):
        pytest.skip('lockdown without EFI/MOK: stap cannot sign modules\n'
                    + result.describe())
    machine = os.uname().machine
    if machine not in ('x86_64', 'amd64'):
        pytest.skip('therm_throt_process is Intel only; not available on {}\n{}'.format(
            machine, result.describe()))
    pytest.fail('therm_throt_process missing on x86_64\n' + result.describe())
