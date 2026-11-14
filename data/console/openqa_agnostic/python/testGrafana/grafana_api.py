#!/usr/bin/python3
"""Shared helpers for the openQA-agnostic Grafana tests.

The functions only use the Python standard library so the test runs on a
minimal SLE 15 image with Python 3.6. Service management is kept here so the
test files stay focused on the assertions.
"""

import json
import os
from http import cookiejar
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request

BASE = 'http://127.0.0.1:3000'
SERVICE = 'grafana-server'


def _opener():
    return urllib.request.build_opener(
        urllib.request.ProxyHandler({}),
        urllib.request.HTTPCookieProcessor(cookiejar.CookieJar()),
    )


def http(method, path, data=None, raw_data=None, content_type=None,
         opener=None, timeout=60):
    """Return (status_code, body) for one request."""
    headers = {}
    body = None
    if raw_data is not None:
        body = raw_data
        headers['Content-Type'] = content_type or 'application/octet-stream'
    elif data is not None:
        body = json.dumps(data).encode('utf-8')
        headers['Content-Type'] = 'application/json'
    request = urllib.request.Request(BASE + path, data=body, headers=headers, method=method)
    client = opener or _opener()
    try:
        response = client.open(request, timeout=timeout)
        return response.getcode(), response.read().decode('utf-8', 'replace')
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode('utf-8', 'replace')


def api_json(opener, method, path, data=None, timeout=60):
    code, body = http(method, path, data=data, opener=opener, timeout=timeout)
    try:
        return code, json.loads(body)
    except ValueError:
        return code, body


def systemctl(*args):
    return subprocess.run(
        ['systemctl', '--no-pager'] + list(args),
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True,
    )


def service_active():
    return systemctl('is-active', '--quiet', SERVICE).returncode == 0


def service_start():
    result = systemctl('start', SERVICE)
    if result.returncode != 0:
        raise RuntimeError('could not start %s: %s' % (SERVICE, result.stderr))


def service_stop():
    systemctl('stop', SERVICE)


def service_restart():
    result = systemctl('restart', SERVICE)
    if result.returncode != 0:
        raise RuntimeError('could not restart %s: %s' % (SERVICE, result.stderr))


def wait_healthy(timeout=180):
    deadline = time.time() + timeout
    last = ''
    while time.time() < deadline:
        try:
            code, body = http('GET', '/api/health', timeout=5)
            if code == 200:
                return json.loads(body)
            last = 'HTTP %s' % code
        except Exception as error:  # connection refused while starting
            last = str(error)
        time.sleep(2)
    raise RuntimeError('Grafana did not become healthy: %s' % last)


def version_parts(version):
    parts = []
    for item in version.split('.')[:3]:
        digits = ''
        for char in item:
            if char.isdigit():
                digits += char
            else:
                break
        parts.append(int(digits or 0))
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts)


def at_least(version, wanted):
    return version_parts(version) >= version_parts(wanted)


def force_cve_checks():
    """Bypass the version gates for negative validation against old versions.

    Set GRAFANA_TEST_FORCE_CVE=1 only when you want the CVE checks to run on
    a Grafana version that predates the fix, for example in a throwaway
    container. Production runs keep the default skip behavior.
    """
    return os.environ.get('GRAFANA_TEST_FORCE_CVE') == '1'


def get_version():
    code, body = api_json(None, 'GET', '/api/health')
    if code != 200:
        raise RuntimeError('cannot read /api/health: HTTP %s' % code)
    return body['version']


def datasource_type(version):
    return 'grafana-testdata-datasource' if at_least(version, '10.0') else 'testdata'


def login(user, password):
    opener = _opener()
    code, body = http('POST', '/login',
                      data={'user': user, 'password': password}, opener=opener)
    if code != 200:
        raise AssertionError('login as %s failed: HTTP %s %s' % (user, code, body))
    return opener


def login_admin():
    return login('admin', 'admin')


def create_testdata_datasource(opener, name='openQA testdata'):
    version = get_version()
    code, body = api_json(opener, 'POST', '/api/datasources', data={
        'name': name,
        'type': datasource_type(version),
        'access': 'proxy',
    })
    if code not in (200, 409):
        raise AssertionError('cannot create datasource: HTTP %s %s' % (code, body))
    quoted = urllib.parse.quote(name, safe='')
    code, body = api_json(opener, 'GET', '/api/datasources/name/' + quoted)
    if code != 200:
        raise AssertionError('cannot read datasource: HTTP %s %s' % (code, body))
    return body['uid']


def delete_datasource(opener, uid):
    http('DELETE', '/api/datasources/uid/' + uid, opener=opener)


def create_dashboard(opener, uid, title, with_panel=False):
    panel = [{
        'type': 'text', 'title': 'openQA',
        'gridPos': {'x': 0, 'y': 0, 'w': 12, 'h': 8},
        'options': {'content': 'openQA'},
    }] if with_panel else []
    code, body = api_json(opener, 'POST', '/api/dashboards/db', data={
        'dashboard': {'uid': uid, 'title': title, 'panels': panel, 'version': 0},
        'overwrite': True,
    })
    return code, body


def delete_dashboard(opener, uid):
    http('DELETE', '/api/dashboards/uid/' + uid, opener=opener)


def create_viewer(opener, login_name='openqa-viewer', password='openqa-viewer-1'):
    code, body = api_json(opener, 'POST', '/api/admin/users', data={
        'name': login_name,
        'email': login_name + '@example.com',
        'login': login_name,
        'password': password,
        'OrgId': 1,
    })
    if code not in (200, 412):
        raise AssertionError('cannot create viewer: HTTP %s %s' % (code, body))


def delete_user(opener, login_name):
    code, body = api_json(opener, 'GET',
                          '/api/users/lookup?loginOrEmail=' + login_name)
    if code == 200 and body.get('id'):
        http('DELETE', '/api/admin/users/%s' % body['id'], opener=opener)


def sql_expression_payload(version, datasource_uid, expression):
    return {
        'from': 'now-1h',
        'to': 'now',
        'queries': [
            {
                'refId': 'A',
                'datasource': {'type': datasource_type(version), 'uid': datasource_uid},
                'scenarioId': 'random_walk',
                'seriesCount': 1,
            },
            {
                'refId': 'B',
                'datasource': {'uid': '__expr__', 'type': '__expr__'},
                'type': 'sql',
                'expression': expression,
            },
        ],
    }
