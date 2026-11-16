# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

import pytest

from xrdp_helpers import RdpEnv, which


def _check_prerequisites(env):
    missing = []
    for command in ('xrdp', 'xrdp-sesman', 'useradd', 'chpasswd', 'pkill',
                    'systemctl', 'rpm', 'ss', 'Xvnc', 'xterm', 'xvfb-run', 'xauth'):
        if not which(command):
            missing.append(command)
    if not env.freerdp:
        missing.append('xfreerdp')
    if missing:
        pytest.skip('missing prerequisites: {}'.format(', '.join(missing)))
    if not env.xrdp_version:
        pytest.skip('cannot determine the installed xrdp version')
    if not env.major:
        pytest.skip('cannot determine the installed FreeRDP version')


@pytest.fixture(scope='session')
def rdp():
    env = RdpEnv()
    try:
        _check_prerequisites(env)
        env.setup()
        yield env
    finally:
        env.teardown()
