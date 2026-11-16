import time

import pytest

from grafana_api import (
    login_admin,
    service_active,
    service_start,
    service_stop,
    wait_healthy,
)


@pytest.fixture(scope='session')
def coredump_baseline():
    return time.strftime('%Y-%m-%d %H:%M:%S')


@pytest.fixture(scope='session')
def grafana(coredump_baseline):
    was_active = service_active()
    if not was_active:
        service_start()
    info = wait_healthy()
    yield info
    if not was_active:
        service_stop()


@pytest.fixture(scope='session')
def admin(grafana):
    return login_admin()
