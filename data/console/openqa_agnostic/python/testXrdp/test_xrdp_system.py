# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

import pytest

from xrdp_helpers import (CHKPRIV, PORT, get_ini_value, port_open, rpm_version,
                          run, which)


def test_package_installed(rdp):
    result = run(['rpm', '-q', 'xrdp'])
    assert result.returncode == 0, result.stdout
    assert rpm_version('xrdp'), 'cannot read the xrdp version from RPM'


def test_services_active(rdp):
    # Runtime state after the fixture started the services; the shipped-state
    # checks are test_package_installed, test_unit_enablement and
    # test_xvnc_backend_present.
    for unit in ('xrdp', 'xrdp-sesman'):
        result = run(['systemctl', 'is-active', unit])
        assert result.returncode == 0, '{} is not active: {}'.format(unit, result.stdout)


def test_listener(rdp):
    # Runtime state after setup(), not a check of the shipped configuration.
    assert port_open(), 'xrdp is not listening on 127.0.0.1:{}'.format(PORT)


def test_version_reported_by_binary(rdp):
    result = run(['xrdp', '--version'])
    assert result.returncode == 0, result.stdout
    major_minor = '.'.join(rdp.xrdp_version.split('.')[:2])
    assert major_minor in result.stdout, \
        'xrdp --version does not report the RPM version {}: {}'.format(major_minor, result.stdout)


def test_unit_enablement(rdp):
    assert rdp.unit_states, 'unit states were not recorded before setup'
    for unit, original in rdp.unit_states.items():
        result = run(['systemctl', 'show', '-p', 'UnitFileState', '--value', unit])
        assert result.returncode == 0, result.stdout
        state = result.stdout.strip()
        assert state, 'no UnitFileState for {}'.format(unit)
        assert state != 'masked', '{} is masked'.format(unit)
        assert state == original, \
            '{} enablement changed from {} to {}'.format(unit, original, state)
        print('{} UnitFileState={} (unchanged)'.format(unit, state))


def test_xvnc_backend_present(rdp):
    # Check the shipped files from the backup, not the test-modified ones.
    xrdp_ini = rdp.backup_dir / 'xrdp.ini'
    sesman_ini = rdp.backup_dir / 'sesman.ini'
    assert xrdp_ini.exists() and sesman_ini.exists()
    assert get_ini_value(xrdp_ini, 'Xvnc', 'lib') == 'libvnc.so'
    assert get_ini_value(xrdp_ini, 'Xvnc', 'port') == '-1'

    # duplicate param= keys are valid in sesman.ini; the line parser must
    # return the first one without requiring configparser semantics
    in_xvnc = False
    params = []
    for line in sesman_ini.read_text().splitlines():
        stripped = line.strip()
        if stripped.startswith('[') and stripped.endswith(']'):
            in_xvnc = stripped[1:-1] == 'Xvnc'
        elif in_xvnc and stripped.startswith('param='):
            params.append(stripped.split('=', 1)[1])
    assert params and params[0] == 'Xvnc', params
    assert len(params) > 1, 'expected duplicate param= keys in sesman.ini [Xvnc]'

    assert which('Xvnc'), 'the Xvnc binary is not installed'
    listing = run(['rpm', '-ql', 'xrdp']).stdout
    assert any(path.endswith('/libvnc.so') for path in listing.splitlines()), \
        'the xrdp package does not ship libvnc.so'


def test_xrdp_chkpriv(rdp):
    if not CHKPRIV.exists():
        pytest.skip('{} is not shipped by this xrdp version'.format(CHKPRIV))
    result = run([str(CHKPRIV)], timeout=60)
    assert '[  NG  ]' not in result.stdout, result.stdout
    assert result.returncode == 0, result.stdout


def test_systemd_units_verify(rdp):
    if not which('systemd-analyze'):
        pytest.skip('systemd-analyze is not available')
    for unit in ('xrdp.service', 'xrdp-sesman.service'):
        result = run(['systemd-analyze', 'verify', unit], timeout=60)
        assert result.returncode == 0, result.stdout
