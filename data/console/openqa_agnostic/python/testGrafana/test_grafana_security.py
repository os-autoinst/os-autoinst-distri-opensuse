#!/usr/bin/python3
"""Regression checks for Grafana CVEs that are observable over the API.

Every check is version-gated: a skip is reported for versions that predate
the fix instead of silently passing or failing on an out-of-scope package.
"""

import os
import subprocess
import tempfile

import pytest

from grafana_api import (
    BASE,
    api_json,
    at_least,
    create_dashboard,
    create_testdata_datasource,
    create_viewer,
    delete_dashboard,
    delete_datasource,
    delete_user,
    force_cve_checks,
    get_version,
    http,
    login,
    service_restart,
    sql_expression_payload,
    systemctl,
    datasource_type,
    wait_healthy,
)

TRAVERSAL_PATHS = [
    '/public/plugins/alertlist/../../../../../../../../etc/passwd',
    '/public/plugins/alertlist/../../../../../../../../etc/passwd.md',
    '/public/plugins/alertlist/../../../../../../../../etc/passwd.csv',
    '/public/plugins/alertlist/%2e%2e/%2e%2e/%2e%2e/%2e%2e/etc/passwd',
]


@pytest.mark.parametrize('path', TRAVERSAL_PATHS)
def test_plugin_path_traversal(grafana, path):
    version = get_version()
    if not force_cve_checks() and not at_least(version, '8.3.1'):
        pytest.skip('path traversal was fixed in 8.3.1, found %s' % version)

    handle, output = tempfile.mkstemp(prefix='grafana-traversal-')
    os.close(handle)
    try:
        result = subprocess.run(
            ['curl', '-sS', '--path-as-is', '-o', output, '-w', '%{http_code}',
             BASE + path],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True,
        )
        assert result.returncode == 0, result.stderr
        with open(output, 'rb') as leaked:
            content = leaked.read()
        assert b'root:x:0:0:' not in content, \
            'path traversal returned /etc/passwd for %s (HTTP %s)' % (path, result.stdout.strip())
    finally:
        os.unlink(output)


def test_anonymous_snapshot(grafana):
    code, body = http('POST', '/api/snapshots', data={
        'dashboard': {'title': 'anonymous', 'panels': []},
        'name': 'anonymous',
    })
    assert code == 401, 'anonymous snapshot creation returned HTTP %s: %s' % (code, body)


@pytest.fixture
def sql_expressions(grafana):
    version = get_version()
    if not force_cve_checks() and not at_least(version, '11.0'):
        pytest.skip('SQL expressions need Grafana 11.0 or newer, found %s' % version)

    dropin_dir = '/etc/systemd/system/grafana-server.service.d'
    dropin = os.path.join(dropin_dir, 'openqa-sql-expressions.conf')
    saved = None
    if os.path.exists(dropin):
        with open(dropin) as handle:
            saved = handle.read()
    os.makedirs(dropin_dir, exist_ok=True)
    with open(dropin, 'w') as handle:
        handle.write('[Service]\nEnvironment=GF_FEATURE_TOGGLES_ENABLE=sqlExpressions\n')
    assert systemctl('daemon-reload').returncode == 0
    service_restart()
    wait_healthy()
    try:
        yield
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


def test_sql_expressions_file_read(admin, sql_expressions):
    version = get_version()
    datasource_uid = create_testdata_datasource(admin, 'openQA sqlExpressions')
    try:
        code, body = api_json(
            admin, 'POST', '/api/ds/query',
            data=sql_expression_payload(version, datasource_uid, 'SELECT * FROM A'),
        )
        results = body.get('results', {}) if isinstance(body, dict) else {}
        if results.get('B', {}).get('status') != 200:
            pytest.skip('sqlExpressions feature toggle is not active')

        code, body = api_json(
            admin, 'POST', '/api/ds/query',
            data=sql_expression_payload(
                version, datasource_uid,
                "SELECT CAST(load_file('/etc/hostname') AS CHAR(10000) CHARACTER SET utf8)"),
        )
        results = body.get('results', {}) if isinstance(body, dict) else {}
        error = results.get('B', {}).get('error', '') or str(body)
        markers = ('blocked_node_or_func', 'not in the allowed list', 'file read operations')
        assert any(marker in error for marker in markers), \
            'LOAD_FILE was not blocked: %s' % error
    finally:
        delete_datasource(admin, datasource_uid)


def test_oversized_plugin_resource(admin):
    version = get_version()
    if not force_cve_checks() and not at_least(version, '12.4'):
        pytest.skip('plugin resource body limit needs Grafana 12.4 or newer, found %s' % version)

    handle, path = tempfile.mkstemp(prefix='grafana-oversized-')
    os.close(handle)
    try:
        with open(path, 'wb') as oversized:
            oversized.truncate(130 * 1024 * 1024)
        with open(path, 'rb') as oversized:
            payload = oversized.read()
        code, body = http(
            'POST', '/api/plugins/%s/resources/x' % datasource_type(version),
            raw_data=payload, content_type='application/json', opener=admin, timeout=300,
        )
        assert code == 413, 'oversized plugin request returned HTTP %s, expected 413' % code
    finally:
        os.unlink(path)


def test_viewer_snapshot(admin):
    version = get_version()
    if not force_cve_checks() and not at_least(version, '12.4'):
        pytest.skip('snapshot authorization fix needs Grafana 12.4 or newer, found %s' % version)

    dashboard_uid = 'openqa-snapshot-dashboard'
    code, body = create_dashboard(
        admin, dashboard_uid, 'openQA snapshot dashboard', with_panel=True)
    assert code == 200, 'create dashboard returned HTTP %s: %s' % (code, body)

    viewer = 'openqa-security-viewer'
    password = 'openqa-viewer-1'
    create_viewer(admin, viewer, password)
    try:
        code, body = api_json(admin, 'GET', '/api/dashboards/uid/' + dashboard_uid)
        assert code == 200, 'read dashboard returned HTTP %s' % code
        assert isinstance(body, dict) and body.get('dashboard'), body
        snapshot = {'dashboard': body['dashboard'], 'name': 'openqa-snapshot'}

        session = login(viewer, password)
        code, body = api_json(session, 'POST', '/api/snapshots', data=snapshot)
        assert code != 200, 'a Viewer created a snapshot (HTTP %s)' % code

        code, body = api_json(admin, 'POST', '/api/snapshots', data=snapshot)
        assert code == 200, 'admin snapshot creation returned HTTP %s: %s' % (code, body)
        key = body.get('key')
        assert key, body
        http('DELETE', '/api/snapshots/' + key, opener=admin)
    finally:
        delete_user(admin, viewer)
        delete_dashboard(admin, dashboard_uid)
