# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

import pytest

from xrdp_helpers import (CHKPRIV, PORT, XRDP_INI, get_ini_value, port_open,
                          rpm_version, run, which)


def test_package_installed(rdp):
    result = run(['rpm', '-q', 'xrdp'])
    assert result.returncode == 0, result.stdout
    assert rpm_version('xrdp'), 'cannot read the xrdp version from RPM'


def test_services_active(rdp):
    for unit in ('xrdp', 'xrdp-sesman'):
        result = run(['systemctl', 'is-active', unit])
        assert result.returncode == 0, '{} is not active: {}'.format(unit, result.stdout)


def test_listener(rdp):
    assert port_open(), 'xrdp is not listening on 127.0.0.1:{}'.format(PORT)


def test_version_reported_by_binary(rdp):
    result = run(['xrdp', '--version'])
    assert result.returncode == 0, result.stdout
    major_minor = '.'.join(rdp.xrdp_version.split('.')[:2])
    assert major_minor in result.stdout, \
        'xrdp --version does not report the RPM version {}: {}'.format(major_minor, result.stdout)


def test_xvnc_backend_present(rdp):
    assert get_ini_value(XRDP_INI, 'Xvnc', 'lib') == 'libvnc.so'
    listing = run(['rpm', '-ql', 'xrdp']).stdout
    assert any(path.endswith('/libvnc.so') for path in listing.splitlines()), \
        'the xrdp package does not ship libvnc.so'
    assert which('Xvnc'), 'the Xvnc binary is not installed'


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
