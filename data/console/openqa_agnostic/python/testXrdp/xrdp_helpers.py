# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
"""Helpers for the xrdp/xfreerdp openQA-agnostic test."""

import os
import re
import secrets
import shutil
import signal
import socket
import subprocess
import tempfile
import time
from pathlib import Path

XRDP_INI = Path('/etc/xrdp/xrdp.ini')
SESMAN_INI = Path('/etc/xrdp/sesman.ini')
CHKPRIV = Path('/usr/share/xrdp/xrdp-chkpriv')
TEST_USER = 'rdptest'
HOST = '127.0.0.1'
PORT = 3389


def run(cmd, input_text=None, timeout=60):
    """Run a command and return CompletedProcess with merged stdout/stderr."""
    return subprocess.run(
        cmd,
        input=input_text,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        universal_newlines=True,
        timeout=timeout,
    )


def ignore_errors(func, *args, **kwargs):
    try:
        return func(*args, **kwargs)
    except Exception:
        return None


def run_ok(cmd, input_text=None, timeout=60):
    result = run(cmd, input_text=input_text, timeout=timeout)
    if result.returncode != 0:
        raise AssertionError(
            'command failed (rc={}): {}\n{}'.format(result.returncode, ' '.join(cmd), result.stdout)
        )
    return result


def which(name):
    return shutil.which(name)


def rpm_version(package):
    result = run(['rpm', '-q', '--qf', '%{VERSION}', package], timeout=20)
    if result.returncode != 0:
        return None
    return result.stdout.strip()


def freerdp_binary():
    # freerdp3 ships xfreerdp, the parallel freerdp2 package ships xfreerdp2.
    for name in ('xfreerdp', 'xfreerdp2', 'xfreerdp3'):
        path = which(name)
        if path:
            return path
    return None


def freerdp_major(binary):
    result = run([binary, '/version'], timeout=20)
    match = re.search(r'version\s+(\d+)\.', result.stdout or '')
    return int(match.group(1)) if match else 0


def supports_option(binary, option):
    result = run([binary, '/help'], timeout=20)
    return option in (result.stdout or '')


def set_ini_value(path, section, key, value):
    """Set key=value in section, preserving comments and duplicate keys."""
    lines = path.read_text().splitlines()
    current = None
    replaced = False
    output = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith('[') and stripped.endswith(']'):
            current = stripped[1:-1]
        if current == section and re.match(r'^\s*' + re.escape(key) + r'\s*=', line):
            if not replaced:
                output.append('{}={}'.format(key, value))
                replaced = True
            continue
        output.append(line)
    if not replaced:
        output = []
        current = None
        inserted = False
        for line in lines:
            output.append(line)
            stripped = line.strip()
            if stripped.startswith('[') and stripped.endswith(']'):
                current = stripped[1:-1]
                if current == section and not inserted:
                    output.append('{}={}'.format(key, value))
                    inserted = True
    path.write_text('\n'.join(output) + '\n')


def get_ini_value(path, section, key):
    current = None
    for line in path.read_text().splitlines():
        stripped = line.strip()
        if stripped.startswith('[') and stripped.endswith(']'):
            current = stripped[1:-1]
            continue
        if current == section:
            match = re.match(r'^\s*' + re.escape(key) + r'\s*=\s*(.*)$', line)
            if match:
                return match.group(1).strip()
    return None


def pids_for(user, name):
    result = run(['pgrep', '-u', user, '-x', name], timeout=10)
    if result.returncode != 0:
        return []
    return [int(pid) for pid in result.stdout.split()]


def xorg_pids(user):
    # /usr/bin/Xorg execs Xorg.bin, so the process name is Xorg.bin.
    return pids_for(user, 'Xorg') + pids_for(user, 'Xorg.bin')


def session_pids(user):
    pids = xorg_pids(user)
    for name in ('Xvnc', 'xterm', 'xrdp-chansrv'):
        pids.extend(pids_for(user, name))
    return pids


def wait_until(predicate, timeout, interval=1):
    deadline = time.time() + timeout
    while time.time() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(interval)
    return None


def port_open(host=HOST, port=PORT, timeout=1):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(timeout)
    try:
        return sock.connect_ex((host, port)) == 0
    finally:
        sock.close()


def wait_for_port(timeout=30):
    if not wait_until(lambda: port_open(), timeout):
        raise AssertionError('xrdp did not start listening on {}:{}'.format(HOST, PORT))


def established_connections(port=PORT):
    result = run(['ss', '-tn', 'state', 'established'], timeout=10)
    if result.returncode != 0:
        return []
    needle = ':{}'.format(port)
    return [line for line in result.stdout.splitlines() if needle in line]


def kill_user_processes(user):
    run(['pkill', '-9', '-u', user], timeout=20)
    wait_until(lambda: not session_pids(user), 20)


def client_command(binary, major, password, extra=None):
    """Return (argv, stdin_text) for one client invocation.

    FreeRDP 3 reads the whole command line from stdin, which keeps the
    password out of argv and ps. FreeRDP 2 has no equivalent.
    """
    extra = extra or []
    base = [
        '/v:{}:{}'.format(HOST, PORT),
        '/u:{}'.format(TEST_USER),
        '/cert:ignore',
        '/size:1024x768',
        '/timeout:20000',
        '/log-level:WARN',
    ]
    args = base[0:2] + ['/p:{}'.format(password)] + base[2:] + extra
    if major >= 3 and supports_option(binary, 'args-from'):
        return [binary, '/args-from:stdin'], '\n'.join(args) + '\n'
    return [binary] + args, None


def start_client(binary, major, password, extra=None):
    argv, stdin_text = client_command(binary, major, password, extra)
    cmd = ['xvfb-run', '-a', '-s', '-screen 0 1024x768x24'] + argv
    proc = subprocess.Popen(
        cmd,
        stdin=subprocess.PIPE if stdin_text is not None else subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        universal_newlines=True,
        start_new_session=True,
    )
    if stdin_text is not None:
        try:
            proc.stdin.write(stdin_text)
            proc.stdin.close()
        except (BrokenPipeError, OSError):
            pass
        proc.stdin = None
    return proc


def stop_client(proc):
    """Terminate a client and its xvfb-run process group, returning its output."""
    if proc.poll() is None:
        try:
            os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
        except OSError:
            pass
    try:
        output = proc.communicate(timeout=10)[0]
    except subprocess.TimeoutExpired:
        output = ''
    return output or ''


class RdpEnv(object):
    def __init__(self):
        self.password = secrets.token_urlsafe(18)
        self.backup_dir = Path(tempfile.mkdtemp(prefix='xrdp-agnostic-'))
        self.freerdp = freerdp_binary()
        self.major = freerdp_major(self.freerdp) if self.freerdp else 0
        self.xrdp_version = rpm_version('xrdp') or ''
        self.was_active = False
        self.firewall_added = False
        self.user_created = False

    def _backup(self, path):
        if path.exists():
            shutil.copy2(str(path), str(self.backup_dir / path.name))

    def _restore(self, path):
        backup = self.backup_dir / path.name
        if backup.exists():
            shutil.copy2(str(backup), str(path))

    def _open_firewall(self):
        if not which('firewall-cmd') or run(['systemctl', 'is-active', 'firewalld']).returncode != 0:
            return
        result = run(['firewall-cmd', '--zone=public', '--add-port={}/tcp'.format(PORT)])
        self.firewall_added = result.returncode == 0

    def _close_firewall(self):
        if self.firewall_added:
            run(['firewall-cmd', '--zone=public', '--remove-port={}/tcp'.format(PORT)])
            self.firewall_added = False

    def setup(self):
        self._backup(XRDP_INI)
        self._backup(SESMAN_INI)
        self.was_active = run(['systemctl', 'is-active', 'xrdp']).returncode == 0

        # Start from the shipped config, not from a pre-existing instance.
        run(['systemctl', 'stop', 'xrdp', 'xrdp-sesman'])
        run(['systemctl', 'reset-failed', 'xrdp', 'xrdp-sesman'])
        run(['userdel', '-r', TEST_USER])
        shutil.rmtree('/home/{}'.format(TEST_USER), ignore_errors=True)
        run_ok(['useradd', '-m', '-s', '/bin/bash', TEST_USER])
        self.user_created = True
        run_ok(['chpasswd'], input_text='{}:{}\n'.format(TEST_USER, self.password))

        set_ini_value(XRDP_INI, 'Globals', 'autorun', 'Xvnc')
        set_ini_value(XRDP_INI, 'Logging', 'LogLevel', 'INFO')
        set_ini_value(SESMAN_INI, 'Logging', 'LogLevel', 'INFO')

        # EnableUserWindowManager runs ~/startwm.sh, so the shipped
        # /etc/xrdp/startwm.sh and its desktop-specific probes stay untouched.
        session_script = Path('/home') / TEST_USER / 'startwm.sh'
        session_script.write_text('#!/bin/sh\nexec xterm -geometry 80x24+10+10\n')
        session_script.chmod(0o755)
        ignore_errors(shutil.chown, str(session_script), user=TEST_USER)

        self._open_firewall()
        run_ok(['systemctl', 'start', 'xrdp-sesman', 'xrdp'], timeout=90)
        wait_for_port(30)

    def restart(self):
        run(['systemctl', 'stop', 'xrdp', 'xrdp-sesman'])
        run_ok(['systemctl', 'start', 'xrdp-sesman', 'xrdp'], timeout=90)
        wait_for_port(30)

    def _dump_logs(self):
        paths = [Path('/var/log/xrdp.log'), Path('/var/log/xrdp-sesman.log')]
        home = Path('/home') / TEST_USER
        paths.extend(sorted(home.glob('.xorgxrdp.*.log')))
        paths.append(home / '.xsession-errors')
        for path in paths:
            try:
                lines = path.read_text(errors='replace').splitlines()
            except (OSError, UnicodeError):
                continue
            print('===== {} (last 120 lines) ====='.format(path))
            print('\n'.join(lines[-120:]))
            print('===== end {} ====='.format(path))

    def teardown(self):
        ignore_errors(kill_user_processes, TEST_USER)
        ignore_errors(run, ['systemctl', 'stop', 'xrdp', 'xrdp-sesman'])
        ignore_errors(self._dump_logs)
        ignore_errors(self._restore, XRDP_INI)
        ignore_errors(self._restore, SESMAN_INI)
        if self.was_active:
            ignore_errors(run, ['systemctl', 'start', 'xrdp-sesman', 'xrdp'])
        ignore_errors(self._close_firewall)
        if self.user_created:
            ignore_errors(run, ['userdel', '-r', TEST_USER])
        shutil.rmtree(str(self.backup_dir), ignore_errors=True)
