# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

import pytest

import systemtap_helpers as h


def test_environment(stap_env):
    print(stap_env.versions)
    result = h.stap('-V', timeout=60)
    assert result.returncode == 0, stap_env.failure('stap -V failed', result)


def test_hello_world(stap_env):
    script = 'probe begin { printf("hello world\\n"); exit() }'
    if stap_env.lockdown != 'none':
        # Lockdown blocks loading the unsigned module; the build is what
        # this suite tests, so a pass-4 build still covers it.
        print('kernel lockdown is active; building only')
        result = h.stap('-p4', '-e', script)
        if result.returncode != 0 and h.signing_unavailable(result):
            pytest.skip('lockdown without EFI/MOK: stap cannot sign modules\n'
                        + result.describe())
        assert result.returncode == 0, stap_env.failure('hello world build failed', result)
        return
    result = h.stap('-e', script)
    assert result.returncode == 0, stap_env.failure('hello world script failed', result)
    assert 'hello world' in result.stdout, stap_env.failure('no hello world output', result)


def test_bsc1226019_vfs_read(stap_env):
    """Reproducer of bsc#1226019: the runtime module failed to link."""
    if not h.has_kernel_debuginfo():
        pytest.fail('vfs.read is a DWARF probe and the running kernel has no '
                    'debuginfo installed\n' + stap_env.versions)
    script = 'probe vfs.read {printf("read performed\\n"); exit()}'
    if stap_env.lockdown != 'none':
        print('kernel lockdown is active; building only')
        result = h.stap('-p4', '-v', '-e', script)
        if result.returncode != 0 and h.signing_unavailable(result):
            pytest.skip('lockdown without EFI/MOK: stap cannot sign modules\n'
                        + result.describe())
        assert result.returncode == 0, stap_env.failure('vfs.read build failed', result)
        return
    result = h.stap('-v', '-e', script)
    assert result.returncode == 0, stap_env.failure('vfs.read probe failed', result)
    assert 'read performed' in result.stdout, stap_env.failure('probe did not fire', result)


def test_cpu_throttle_pass4(stap_env, cpu_throttle, throttle_support):
    """cpu_throttle.meta test_check; kprobe based, so no debuginfo needed."""
    result = h.stap('-p4', cpu_throttle)
    if result.returncode != 0 and h.signing_unavailable(result):
        pytest.skip('lockdown without EFI/MOK: stap cannot sign modules\n'
                    + result.describe())
    assert result.returncode == 0, stap_env.failure('pass-4 build failed', result)


def test_cpu_throttle_runtime(stap_env, cpu_throttle, throttle_support):
    """cpu_throttle.meta test_installcheck: load the module for one second."""
    if stap_env.lockdown != 'none':
        pytest.skip('kernel lockdown is active; loading the module is blocked')
    result = h.stap(cpu_throttle, '-T', '1')
    assert result.returncode == 0, stap_env.failure('cpu_throttle run failed', result)
