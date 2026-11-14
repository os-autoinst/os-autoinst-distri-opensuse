#!/usr/bin/python3
"""Packaging and system-integration checks learned from Fedora's Grafana tests.

Fedora's tmt/beakerlib suite covers the TLS cipher policy, SELinux
confinement, systemd unit validation, the grafana user and data directory,
license metadata, and coredumps. These are the checks that map to the
openSUSE/SUSE package; the Fedora-only packaging conventions (systemd-sysusers,
unsigned PCP plugins) are intentionally not forced onto a different package
layout.
"""

import grp
import os
import pwd
import re
import shutil
import subprocess
import tempfile
import time

import pytest

from grafana_api import at_least, get_version, service_restart, systemctl, wait_healthy

SERVICE = 'grafana-server'
UNIT_DIR = '/usr/lib/systemd/system'
DATA_DIR = '/var/lib/grafana'
SYSCONFIG = '/etc/sysconfig/grafana-server'
PORT = 3000


def run(cmd, timeout=60):
    return subprocess.run(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        universal_newlines=True, timeout=timeout,
    )


def systemd_managed():
    return os.path.isdir('/run/systemd/system')


def rpm_package_installed():
    if shutil.which('rpm') is None:
        return False
    return run(['rpm', '-q', 'grafana'], timeout=30).returncode == 0


def wait_https_healthy(timeout=120):
    deadline = time.time() + timeout
    while time.time() < deadline:
        result = run(['curl', '-ksS', '-o', '/dev/null',
                      'https://127.0.0.1:%d/api/health' % PORT], timeout=10)
        if result.returncode == 0:
            return
        time.sleep(2)
    raise RuntimeError('Grafana did not become healthy over HTTPS')


def test_grafana_user_and_data_dir(grafana):
    if not rpm_package_installed():
        pytest.skip('grafana is not installed by rpm')
    try:
        user = pwd.getpwnam('grafana')
        group = grp.getgrnam('grafana')
    except KeyError as error:
        pytest.fail('grafana user/group is missing: %s' % error)

    assert os.path.isdir(DATA_DIR), '%s is missing' % DATA_DIR
    stat = os.stat(DATA_DIR)
    assert stat.st_uid == user.pw_uid, '%s is not owned by grafana' % DATA_DIR
    assert stat.st_gid == group.gr_gid, '%s is not group grafana' % DATA_DIR

    data_dir = None
    if os.path.exists(SYSCONFIG):
        with open(SYSCONFIG) as handle:
            for line in handle:
                if line.lstrip().startswith('#'):
                    continue
                match = re.match(r'\s*DATA_DIR\s*=\s*"?([^"\s]+)"?', line)
                if match:
                    data_dir = match.group(1)
    if data_dir is not None:
        assert data_dir == DATA_DIR, 'DATA_DIR is %s, expected %s' % (data_dir, DATA_DIR)


def test_systemd_unit_verify():
    if not systemd_managed():
        pytest.skip('systemd is not managing this system')
    if not rpm_package_installed() or shutil.which('systemd-analyze') is None:
        pytest.skip('rpm or systemd-analyze is not available')

    files = run(['rpm', '-ql', 'grafana'], timeout=30)
    assert files.returncode == 0, files.stderr
    units = [line for line in files.stdout.splitlines()
             if line.startswith(UNIT_DIR) and line.endswith('.service')]
    assert units, 'the package does not ship a systemd service unit'

    for unit in units:
        unit_name = os.path.basename(unit)
        verify = run(['systemd-analyze', 'verify', unit])
        output = verify.stdout + verify.stderr
        assert verify.returncode == 0, \
            'systemd-analyze verify failed for %s: %s' % (unit, output)
        relevant = [line for line in output.splitlines() if unit_name in line]
        assert not any(re.search(r'Fail|Warn|Error|Unknown', line, re.I) for line in relevant), \
            'systemd-analyze verify reported a problem for %s: %s' % (unit, '\n'.join(relevant))


def test_license_identifier():
    if not rpm_package_installed():
        pytest.skip('grafana is not installed by rpm')
    result = run(['rpm', '-q', '--qf', '%{license}\n', 'grafana'], timeout=30)
    assert result.returncode == 0, result.stderr
    license_text = result.stdout.strip()
    assert license_text and license_text != '(none)', \
        'grafana has no license metadata'
    assert re.match(r'^[A-Za-z0-9.+-]+( (AND|OR) [A-Za-z0-9.+-]+)*$', license_text), \
        'license is not an SPDX-like expression: %s' % license_text


def test_selinux_confinement(grafana):
    if not os.path.exists('/sys/fs/selinux/enforce'):
        pytest.skip('SELinux is not enabled')
    with open('/sys/fs/selinux/enforce') as handle:
        if handle.read().strip() == '0':
            pytest.skip('SELinux is not enforcing')

    has_policy = False
    if shutil.which('semodule'):
        result = run(['semodule', '-l'], timeout=60)
        has_policy = 'grafana' in result.stdout
    if not has_policy and shutil.which('semanage'):
        result = run(['semanage', 'fcontext', '-l'], timeout=60)
        has_policy = 'grafana' in result.stdout
    if not has_policy:
        pytest.skip('no Grafana SELinux policy is installed')

    processes = run(['ps', '-eo', 'label,comm'], timeout=30)
    for line in processes.stdout.splitlines():
        fields = line.split(None, 1)
        if len(fields) == 2 and fields[1].startswith('grafana') and 'unconfined' in fields[0]:
            pytest.fail('Grafana runs unconfined despite a shipped policy: %s' % line)


def test_tls_cipher_allowlist(grafana):
    if not systemd_managed():
        pytest.skip('systemd is not managing this system')
    if shutil.which('nmap') is None or shutil.which('openssl') is None:
        pytest.skip('nmap or openssl is not available')
    version = get_version()
    if not at_least(version, '10.0'):
        pytest.skip('TLS cipher policy check needs Grafana 10.0 or newer, found %s' % version)

    # PrivateTmp=true hides /tmp from grafana-server, so keep the certs
    # under /etc/grafana where the service can read them.
    workdir = tempfile.mkdtemp(prefix='openqa-tls-', dir='/etc/grafana')
    os.chmod(workdir, 0o755)
    cert = os.path.join(workdir, 'server.crt')
    key = os.path.join(workdir, 'server.key')
    dropin_dir = '/etc/systemd/system/grafana-server.service.d'
    dropin = os.path.join(dropin_dir, 'openqa-tls.conf')
    saved = None
    if os.path.exists(dropin):
        with open(dropin) as handle:
            saved = handle.read()

    try:
        result = run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
                      '-subj', '/CN=localhost', '-keyout', key, '-out', cert,
                      '-days', '1'])
        assert result.returncode == 0, result.stderr
        os.chmod(cert, 0o644)
        os.chmod(key, 0o644)

        os.makedirs(dropin_dir, exist_ok=True)
        with open(dropin, 'w') as handle:
            handle.write(
                '[Service]\n'
                'Environment=GF_SERVER_PROTOCOL=https\n'
                'Environment=GF_SERVER_CERT_FILE=%s\n'
                'Environment=GF_SERVER_CERT_KEY=%s\n' % (cert, key)
            )
        assert systemctl('daemon-reload').returncode == 0
        service_restart()
        wait_https_healthy()

        result = run(['nmap', '--script', 'ssl-enum-ciphers',
                      '-p', str(PORT), '127.0.0.1'], timeout=120)
        assert result.returncode == 0, result.stderr
        weak = [line for line in result.stdout.splitlines()
                if re.search(r'-\s+[B-FT]$', line.strip())]
        assert not weak, 'weak TLS ciphers negotiated:\n%s' % '\n'.join(weak)
    finally:
        if saved is not None:
            with open(dropin, 'w') as handle:
                handle.write(saved)
        elif os.path.exists(dropin):
            os.remove(dropin)
        try:
            os.rmdir(dropin_dir)
        except OSError:
            pass
        assert systemctl('daemon-reload').returncode == 0
        service_restart()
        wait_healthy()
        shutil.rmtree(workdir, ignore_errors=True)


def test_no_grafana_coredumps(coredump_baseline):
    if shutil.which('coredumpctl') is None:
        pytest.skip('coredumpctl is not available')
    result = run(['coredumpctl', '--no-pager', 'list', '--since', coredump_baseline])
    output = result.stdout + result.stderr
    if result.returncode != 0:
        assert 'No coredumps found' in output, 'coredumpctl failed: %s' % output
        return
    grafana_cores = [line for line in result.stdout.splitlines() if 'grafana' in line]
    assert not grafana_cores, \
        'new Grafana coredumps since %s:\n%s' % (coredump_baseline, '\n'.join(grafana_cores))
