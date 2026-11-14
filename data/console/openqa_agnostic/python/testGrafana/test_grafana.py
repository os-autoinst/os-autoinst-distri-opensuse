#!/usr/bin/python3
"""Functional and API tests for the installed Grafana package.

Mirrors the useful part of Grafana's own ``@acceptance`` smoke suite without
Node/Yarn: health, admin login, bundled plugin, datasource query, dashboard
lifecycle, file provisioning, restart persistence and basic RBAC.
"""

import json
import os
import shutil
import tempfile


from grafana_api import (
    api_json,
    create_dashboard,
    create_testdata_datasource,
    create_viewer,
    delete_dashboard,
    delete_datasource,
    delete_user,
    get_version,
    login,
    service_restart,
    datasource_type,
    wait_healthy,
)

DASHBOARD_UID = 'openqa-grafana-dashboard'
PROV_DASHBOARD_UID = 'openqa-prov-dash'
PROV_DATASOURCE_UID = 'openqa-prov-ds'
PROVISIONING = '/etc/grafana/provisioning'
DASHBOARD_DIR = '/var/lib/grafana/openqa-dashboards'


def test_health(grafana):
    assert grafana.get('database') == 'ok', 'health database is %r' % grafana.get('database')
    assert grafana.get('version'), 'health did not report a version'


def test_admin_login(admin):
    code, body = api_json(admin, 'GET', '/api/user')
    assert code == 200, 'GET /api/user returned HTTP %s: %s' % (code, body)
    assert body.get('login') == 'admin', body
    assert body.get('isGrafanaAdmin') is True, body


def test_bundled_testdata_plugin(admin):
    version = get_version()
    plugin_id = datasource_type(version)
    code, body = api_json(admin, 'GET', '/api/plugins?type=datasource')
    assert code == 200, 'GET /api/plugins returned HTTP %s' % code
    plugins = body.get('plugins', []) if isinstance(body, dict) else body
    found = [p for p in plugins if p.get('id') == plugin_id and p.get('enabled')]
    assert found, 'bundled %s plugin is missing or disabled' % plugin_id


def test_datasource_query(admin):
    version = get_version()
    datasource_uid = create_testdata_datasource(admin)
    try:
        payload = {
            'from': 'now-1h',
            'to': 'now',
            'queries': [{
                'refId': 'A',
                'datasource': {'type': datasource_type(version), 'uid': datasource_uid},
                'scenarioId': 'random_walk',
                'seriesCount': 1,
            }],
        }
        code, body = api_json(admin, 'POST', '/api/ds/query', data=payload)
        assert code == 200, 'query returned HTTP %s: %s' % (code, body)
        results = body.get('results', {}) if isinstance(body, dict) else {}
        frames = results.get('A', {}).get('frames', [])
        assert frames, 'query returned no frames: %s' % body
    finally:
        delete_datasource(admin, datasource_uid)


def test_dashboard_lifecycle(admin):
    code, body = create_dashboard(admin, DASHBOARD_UID, 'openQA Grafana test')
    assert code == 200, 'create dashboard returned HTTP %s: %s' % (code, body)
    try:
        code, body = api_json(admin, 'GET', '/api/dashboards/uid/' + DASHBOARD_UID)
        assert code == 200, 'read dashboard returned HTTP %s' % code
        dashboard = body.get('dashboard', {}) if isinstance(body, dict) else {}
        assert dashboard.get('title') == 'openQA Grafana test', body
        code, body = api_json(admin, 'GET', '/api/search?query=openQA')
        assert code == 200, 'search returned HTTP %s' % code
        assert any(item.get('uid') == DASHBOARD_UID for item in body), body
    finally:
        delete_dashboard(admin, DASHBOARD_UID)


def _write_provisioning(version):
    os.makedirs(os.path.join(PROVISIONING, 'datasources'), exist_ok=True)
    os.makedirs(os.path.join(PROVISIONING, 'dashboards'), exist_ok=True)
    os.makedirs(DASHBOARD_DIR, exist_ok=True)
    with open(os.path.join(PROVISIONING, 'datasources', 'openqa.yaml'), 'w') as handle:
        handle.write(
            'apiVersion: 1\n'
            'datasources:\n'
            '  - name: openQA provisioned\n'
            '    type: %s\n'
            '    access: proxy\n'
            '    uid: %s\n' % (datasource_type(version), PROV_DATASOURCE_UID)
        )
    dashboard = {
        'uid': PROV_DASHBOARD_UID,
        'title': 'openQA provisioned dashboard',
        'panels': [],
        'version': 0,
    }
    dashboard_path = os.path.join(DASHBOARD_DIR, 'openqa.json')
    with open(dashboard_path, 'w') as handle:
        json.dump(dashboard, handle)
    shutil.chown(dashboard_path, user='grafana', group='grafana')
    with open(os.path.join(PROVISIONING, 'dashboards', 'openqa.yaml'), 'w') as handle:
        handle.write(
            'apiVersion: 1\n'
            'providers:\n'
            '  - name: openQA\n'
            '    orgId: 1\n'
            '    folder: ""\n'
            '    type: file\n'
            '    updateIntervalSeconds: 10\n'
            '    options:\n'
            '      path: %s\n' % DASHBOARD_DIR
        )


def test_provisioning(admin):
    backup = tempfile.mkdtemp(prefix='grafana-provisioning-')
    saved = os.path.join(backup, 'provisioning')
    had_provisioning = os.path.isdir(PROVISIONING)
    if had_provisioning:
        shutil.copytree(PROVISIONING, saved)
    try:
        _write_provisioning(get_version())
        service_restart()
        wait_healthy()
        code, body = api_json(admin, 'GET', '/api/datasources/uid/' + PROV_DATASOURCE_UID)
        assert code == 200, 'provisioned datasource returned HTTP %s' % code
        assert isinstance(body, dict) and body.get('name') == 'openQA provisioned', body
        code, body = api_json(admin, 'GET', '/api/dashboards/uid/' + PROV_DASHBOARD_UID)
        assert code == 200, 'provisioned dashboard returned HTTP %s' % code
        dashboard = body.get('dashboard', {}) if isinstance(body, dict) else {}
        assert dashboard.get('title') == 'openQA provisioned dashboard', body
    finally:
        shutil.rmtree(PROVISIONING, ignore_errors=True)
        if had_provisioning:
            shutil.copytree(saved, PROVISIONING)
        else:
            os.makedirs(PROVISIONING)
        shutil.rmtree(DASHBOARD_DIR, ignore_errors=True)
        shutil.rmtree(backup, ignore_errors=True)
        service_restart()
        wait_healthy()


def test_dashboard_persistence(admin):
    code, body = create_dashboard(admin, DASHBOARD_UID, 'openQA Grafana test')
    assert code == 200, 'create dashboard returned HTTP %s: %s' % (code, body)
    try:
        service_restart()
        wait_healthy()
        code, body = api_json(admin, 'GET', '/api/dashboards/uid/' + DASHBOARD_UID)
        assert code == 200, 'dashboard did not survive restart (HTTP %s)' % code
        dashboard = body.get('dashboard', {}) if isinstance(body, dict) else {}
        assert dashboard.get('title') == 'openQA Grafana test', body
    finally:
        delete_dashboard(admin, DASHBOARD_UID)


def test_viewer_rbac(admin):
    viewer = 'openqa-viewer'
    password = 'openqa-viewer-1'
    code, body = create_dashboard(admin, DASHBOARD_UID, 'openQA Grafana test')
    assert code == 200, 'create dashboard returned HTTP %s: %s' % (code, body)
    create_viewer(admin, viewer, password)
    try:
        session = login(viewer, password)
        # Older Grafana releases may not expose /api/user/orgs. The
        # behaviour checks below are the property under test; only assert the
        # role name when the endpoint exists.
        code, body = api_json(session, 'GET', '/api/user/orgs')
        if code == 200 and isinstance(body, list):
            roles = [org.get('role') for org in body if org.get('orgId') == 1]
            assert roles == ['Viewer'], 'viewer has roles %r' % roles

        code, body = api_json(session, 'GET', '/api/dashboards/uid/' + DASHBOARD_UID)
        assert code == 200, 'viewer cannot read a dashboard (HTTP %s)' % code

        code, body = api_json(session, 'POST', '/api/datasources', data={
            'name': 'viewer-datasource',
            'type': datasource_type(get_version()),
            'access': 'proxy',
        })
        assert code != 200, 'viewer was allowed to create a datasource'

        code, body = api_json(session, 'POST', '/api/dashboards/db', data={
            'dashboard': {'uid': 'viewer-dashboard', 'title': 'viewer', 'panels': []},
            'overwrite': True,
        })
        assert code != 200, 'viewer was allowed to save a dashboard'

        code, body = api_json(session, 'GET', '/api/admin/users')
        assert code != 200, 'viewer was allowed to list admin users'
    finally:
        delete_user(admin, viewer)
        delete_dashboard(admin, DASHBOARD_UID)
