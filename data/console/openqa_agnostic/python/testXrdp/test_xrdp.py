# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

import platform
import re
import time
from pathlib import Path

import pytest

from xrdp_helpers import (SESMAN_INI, TEST_USER, XRDP_INI, client_output,
                          coredump_since, get_ini_value, journal_kernel_since,
                          journal_since, kill_user_processes, pids_for, run,
                          session_pids, set_ini_value, start_client, stop_client,
                          wait_until, which, xorg_pids, xrdp_tcp_connections)


@pytest.fixture(autouse=True)
def clean_sessions(rdp):
    kill_user_processes(TEST_USER)
    yield


def _connect(rdp, password=None):
    return start_client(rdp.freerdp, rdp.major, password or rdp.password,
                        rdp.args_from)


def _expect_session(rdp, proc, timeout=60):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if proc.poll() is not None:
            pytest.fail('client exited before a session started (rc={}):\n{}'.format(
                proc.returncode, client_output(proc)))
        if session_pids(TEST_USER):
            if proc.poll() is not None:
                pytest.fail('client exited after creating the session (rc={})'.format(
                    proc.returncode))
            return
        time.sleep(1)
    pytest.fail('no session started for {} within {}s; client output:\n{}'.format(
        TEST_USER, timeout, stop_client(proc)))


def _assert_clean_journal(lines, context):
    # Auth-phase failures are expected from the bad-credentials test; only
    # session/account PAM errors indicate the X9 regression.
    pam_errors = [line for line in lines
                  if re.search(r'pam_[^(]*\([^:]+:(session|account)\):'
                               r'.*(error|fail|denied)', line, re.I)]
    assert not pam_errors, '{}: PAM errors:\n{}'.format(context, '\n'.join(pam_errors))


def _assert_no_crashes(start, context):
    kernel = journal_kernel_since(start)
    if kernel is None:
        pytest.skip('journalctl -k could not be read')
    crashes = [line for line in kernel
               if re.search(r'segfault|general protection|traps:', line, re.I)
               and re.search(r'xrdp|Xvnc|xterm|chansrv', line, re.I)]
    cores = coredump_since(start)
    if cores:
        crashes.extend(line for line in cores
                       if re.search(r'xrdp|Xvnc|xterm|chansrv', line, re.I))
    assert not crashes, '{}: crashes:\n{}'.format(context, '\n'.join(crashes))


def test_good_credentials_start_session(rdp):
    proc = _connect(rdp)
    try:
        _expect_session(rdp, proc)
        assert wait_until(lambda: pids_for(TEST_USER, 'Xvnc'), 30), \
            'Xvnc is not running for the test user'
        assert wait_until(lambda: pids_for(TEST_USER, 'xterm'), 30), \
            'the xterm session is not running for the test user'
    finally:
        stop_client(proc)


def test_bad_credentials_create_no_session(rdp):
    for attempt in range(3):
        proc = _connect(rdp, password='wrong-password-{}'.format(attempt))
        try:
            deadline = time.time() + 15
            while time.time() < deadline and proc.poll() is None and not session_pids(TEST_USER):
                time.sleep(1)
            pids = session_pids(TEST_USER)
            assert not pids, 'a wrong password created a session: {}'.format(pids)
        finally:
            stop_client(proc)
            kill_user_processes(TEST_USER)


def test_reconnect_after_disconnect(rdp):
    start = time.time()
    proc = _connect(rdp)
    try:
        _expect_session(rdp, proc)
        assert wait_until(lambda: pids_for(TEST_USER, 'Xvnc'), 15), \
            'Xvnc is not running before the disconnect'
        xvnc_before = pids_for(TEST_USER, 'Xvnc')
        assert len(xvnc_before) == 1, \
            'expected one Xvnc before reconnect: {}'.format(xvnc_before)
    finally:
        stop_client(proc)

    assert wait_until(lambda: not xrdp_tcp_connections(), 15), \
        'the old RDP connection did not close'
    # The default KillDisconnected=false keeps the session for a reconnect.
    assert wait_until(lambda: session_pids(TEST_USER), 15), \
        'the session disappeared after the client disconnected'
    assert run(['systemctl', 'is-active', 'xrdp-sesman']).returncode == 0

    proc = _connect(rdp)
    try:
        deadline = time.time() + 30
        while time.time() < deadline:
            if proc.poll() is not None:
                pytest.fail('client exited before reconnecting (rc={}):\n{}'.format(
                    proc.returncode, client_output(proc)))
            if pids_for(TEST_USER, 'Xvnc') == xvnc_before:
                break
            time.sleep(1)
        else:
            pytest.fail('reconnect did not reuse the existing Xvnc session; '
                        'before={} now={}'.format(
                            xvnc_before, pids_for(TEST_USER, 'Xvnc')))
        time.sleep(3)
        assert proc.poll() is None, 'client exited after reconnecting'
        assert pids_for(TEST_USER, 'Xvnc') == xvnc_before, \
            'reconnect did not reuse the existing Xvnc session'
        assert len(pids_for(TEST_USER, 'Xvnc')) == 1, \
            'expected exactly one Xvnc after reconnect'
        assert run(['systemctl', 'is-active', 'xrdp-sesman']).returncode == 0, \
            'xrdp-sesman is not active after reconnecting'
        lines = journal_since(start)
        if lines is None:
            pytest.skip('journalctl could not read the xrdp units')
        _assert_clean_journal(lines, 'reconnect')
        _assert_no_crashes(start, 'reconnect')
    finally:
        stop_client(proc)


def test_second_session_after_disconnect(rdp):
    start = time.time()
    proc = _connect(rdp)
    try:
        _expect_session(rdp, proc)
        assert wait_until(lambda: pids_for(TEST_USER, 'Xvnc'), 15), \
            'Xvnc is not running before the disconnect'
        xvnc_before = pids_for(TEST_USER, 'Xvnc')
        assert len(xvnc_before) == 1
    finally:
        stop_client(proc)
        kill_user_processes(TEST_USER)

    proc = _connect(rdp)
    try:
        _expect_session(rdp, proc)
        assert wait_until(lambda: pids_for(TEST_USER, 'Xvnc'), 15), \
            'Xvnc is not running after the second login'
        xvnc_now = pids_for(TEST_USER, 'Xvnc')
        assert len(xvnc_now) == 1, \
            'expected one Xvnc after the second login: {}'.format(xvnc_now)
        assert not set(xvnc_now) & set(xvnc_before), \
            'the second login reused the old Xvnc session'
        assert run(['systemctl', 'is-active', 'xrdp-sesman']).returncode == 0, \
            'xrdp-sesman is not active after a second login'
        lines = journal_since(start)
        if lines is None:
            pytest.skip('journalctl could not read the xrdp units')
        _assert_clean_journal(lines, 'second session')
        _assert_no_crashes(start, 'second session')
    finally:
        stop_client(proc)


def test_kill_disconnected(rdp):
    # sesman.ini documents that KillDisconnected only works with xorgxrdp.
    if platform.machine() not in ('x86_64', 'aarch64'):
        pytest.skip('KillDisconnected is only tested with xorgxrdp on x86_64/aarch64')
    if not which('Xorg') or not Path('/etc/X11/xrdp/xorg.conf').exists():
        pytest.skip('KillDisconnected only works with xorgxrdp, which is not installed')
    if get_ini_value(SESMAN_INI, 'Sessions', 'KillDisconnected') is None:
        pytest.skip('KillDisconnected is not configurable in this xrdp version')
    original_autorun = get_ini_value(XRDP_INI, 'Globals', 'autorun')
    original_kill = get_ini_value(SESMAN_INI, 'Sessions', 'KillDisconnected')
    original_limit = get_ini_value(SESMAN_INI, 'Sessions', 'DisconnectedTimeLimit')
    try:
        set_ini_value(XRDP_INI, 'Globals', 'autorun', 'Xorg')
        set_ini_value(SESMAN_INI, 'Sessions', 'KillDisconnected', 'true')
        if original_limit is not None:
            set_ini_value(SESMAN_INI, 'Sessions', 'DisconnectedTimeLimit', '60')
        rdp.restart()
        proc = _connect(rdp)
        try:
            _expect_session(rdp, proc)
            assert wait_until(lambda: xorg_pids(TEST_USER), 30), \
                'Xorg is not running for the test user'
            # Let the client finish the RDP login before disconnecting it.
            time.sleep(3)
        finally:
            stop_client(proc)
        # sesman.ini enforces a 60 second minimum for DisconnectedTimeLimit.
        assert wait_until(lambda: not session_pids(TEST_USER), 120), \
            ('KillDisconnected=true did not remove the disconnected Xorg '
             'session; remaining: {}').format(
                {name: pids_for(TEST_USER, name)
                    for name in ('Xorg', 'Xorg.bin', 'Xvnc', 'xterm', 'xrdp-chansrv')})
    finally:
        set_ini_value(XRDP_INI, 'Globals', 'autorun', original_autorun or 'Xvnc')
        set_ini_value(SESMAN_INI, 'Sessions', 'KillDisconnected', original_kill or 'false')
        if original_limit is not None:
            set_ini_value(SESMAN_INI, 'Sessions', 'DisconnectedTimeLimit', original_limit)
        rdp.restart()
        kill_user_processes(TEST_USER)


def test_xorg_backend(rdp):
    if platform.machine() not in ('x86_64', 'aarch64'):
        pytest.skip('the Xorg backend is only tested on x86_64 and aarch64')
    if not which('Xorg') or not Path('/etc/X11/xrdp/xorg.conf').exists():
        pytest.skip('xorgxrdp is not installed')
    original = get_ini_value(XRDP_INI, 'Globals', 'autorun')
    try:
        set_ini_value(XRDP_INI, 'Globals', 'autorun', 'Xorg')
        rdp.restart()
        proc = _connect(rdp)
        try:
            _expect_session(rdp, proc)
            assert wait_until(lambda: xorg_pids(TEST_USER), 30), \
                'Xorg is not running for the test user'
        finally:
            stop_client(proc)
    finally:
        set_ini_value(XRDP_INI, 'Globals', 'autorun', original or 'Xvnc')
        rdp.restart()
        kill_user_processes(TEST_USER)
