# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
"""Functional tests for the system-wide crypto-policies.

Ported from tests/security/crypto_policies/crypto_policies_tests.pm.

Two modes:

* ``CRYPTO_POLICY`` is not set (standalone): for each of the LEGACY, BSI,
  FUTURE and DEFAULT policies the policy is switched with
  ``update-crypto-policies --set`` and sshd and named are restarted to pick
  it up. The system is not rebooted.
* ``CRYPTO_POLICY=<policy>`` is set (the openQA wrapper): the caller has
  already set the policy and rebooted. The test only checks that this
  policy is the active one, then runs the checks below once.

BIND (DNSSEC validation, rndc, a local zone), GnuTLS (certtool +
gnutls-serv/gnutls-cli) and NSS (certutil + tstclnt against an openssl
s_server) are exercised with the active policy.

Standalone use outside openQA::

    mkdir -p /tmp/cp-agnostic/lib
    cp data/openqa_agnostic/lib/helper.sh /tmp/cp-agnostic/lib/
    cp -r data/security/openqa_agnostic/python/testCryptoPolicies /tmp/cp-agnostic/
    cd /tmp/cp-agnostic/testCryptoPolicies
    sudo ./runtest

The run needs root, Python 3.6+, python3-pytest and the packages
crypto-policies-scripts, bind, gnutls, mozilla-nss-tools and openssl. The
policy is reset to DEFAULT and /etc/named.conf is restored at the end.
"""

import contextlib
import os
import re
import socket
import subprocess
import time

import pytest

# Set when the caller applies the policy (and reboots) itself
EXPECTED_POLICY = os.environ.get("CRYPTO_POLICY")
POLICIES = (EXPECTED_POLICY,) if EXPECTED_POLICY else ("LEGACY", "BSI", "FUTURE", "DEFAULT")
SERVICES = ("sshd", "named")

ZONE_FILE = "/var/lib/named/master/example.com"
ZONE_CONF = "/etc/named.d/example.com.conf"
NAMED_CONF = "/etc/named.conf"
NAMED_INCLUDE = 'include "/etc/named.d/example.com.conf";\n'

ZONE = """$TTL 2D
@\t\tIN SOA\t\tsusetest.\troot.susetest. (
\t\t\t\t2024072601\t; serial
\t\t\t\t3H\t\t; refresh
\t\t\t\t1H\t\t; retry
\t\t\t\t1W\t\t; expiry
\t\t\t\t1D )\t\t; minimum

example.com.\tIN NS\t\tlocalhost.
foobar.example.com. IN A         1.2.3.4
"""

ZONE_CONFIG = """zone "example.com" in {
        allow-transfer { any; };
        file "master/example.com";
        type master;
};
"""

CA_TEMPLATE = "cn = GnuTLS test CA\nca\ncert_signing_key\n"
SERVER_TEMPLATE = (
    "organization = GnuTLS test server\n"
    "cn = localhost\n"
    "tls_www_server\n"
    "encryption_key\n"
    "signing_key\n"
)


def run(cmd, timeout=120, input=None):
    """Run a command and return the CompletedProcess, stderr merged into stdout."""
    return subprocess.run(
        cmd, input=input, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        universal_newlines=True, timeout=timeout,
    )


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def current_policy():
    result = run(["update-crypto-policies", "--show"], timeout=30)
    assert result.returncode == 0, result.stdout
    return result.stdout.strip()


def service_state(name):
    """Return (ActiveState, SubState) of a systemd service."""
    result = run(
        ["systemctl", "show", "-p", "ActiveState", "-p", "SubState", name + ".service"],
        timeout=30,
    )
    props = dict(
        line.split("=", 1) for line in result.stdout.splitlines() if "=" in line
    )
    return props.get("ActiveState"), props.get("SubState")


def restart_service(name, timeout=30):
    result = run(["systemctl", "restart", name + ".service"], timeout=90)
    assert result.returncode == 0, "restarting %s failed: %s" % (name, result.stdout)
    for _ in range(timeout):
        if service_state(name) == ("active", "running"):
            return
        time.sleep(1)
    pytest.fail("%s did not become active (running): %s" % (name, service_state(name)))


def wait_for_text(path, text, proc, timeout=30):
    """Wait until text appears in the log file of a background process."""
    for _ in range(timeout):
        with open(path) as handle:
            log = handle.read()
        if text in log:
            return
        if proc.poll() is not None:
            pytest.fail("process exited early (rc %s): %s" % (proc.returncode, log))
        time.sleep(1)
    pytest.fail("'%s' not found in %s within %ss: %s" % (text, path, timeout, log))


@contextlib.contextmanager
def background(cmd, logfile, ready, timeout=30):
    """Run cmd in the background until the 'ready' text shows up in its log."""
    with open(logfile, "w") as log:
        proc = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT)
        try:
            wait_for_text(logfile, ready, proc, timeout)
            yield proc
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()


def tstclnt_path():
    """The NSS test client lives in a different path on SLES and Tumbleweed."""
    result = run(["rpm", "-ql", "mozilla-nss-tools"], timeout=30)
    for line in result.stdout.splitlines():
        if re.search(r"/usr/lib.*tstclnt", line):
            return line
    pytest.fail("tstclnt not found in mozilla-nss-tools: %s" % result.stdout)


@pytest.fixture(scope="session")
def bind_zone():
    """Serve a local example.com zone with named; restore everything at the end."""
    with open(NAMED_CONF) as handle:
        original_named_conf = handle.read()
    for path, content in ((ZONE_FILE, ZONE), (ZONE_CONF, ZONE_CONFIG)):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as handle:
            handle.write(content)
        os.chmod(path, 0o644)
    if NAMED_INCLUDE not in original_named_conf:
        with open(NAMED_CONF, "a") as handle:
            handle.write(NAMED_INCLUDE)
    for service in SERVICES:
        result = run(["systemctl", "enable", "--now", service + ".service"], timeout=90)
        assert result.returncode == 0, "enabling %s failed: %s" % (service, result.stdout)
    # named may already be running without the zone, make it read the new config
    restart_service("named")
    yield
    # Best effort cleanup, never hide the result of the tests
    with open(NAMED_CONF, "w") as handle:
        handle.write(original_named_conf)
    for path in (ZONE_FILE, ZONE_CONF):
        with contextlib.suppress(OSError):
            os.unlink(path)
    if not EXPECTED_POLICY:
        run(["update-crypto-policies", "--set", "DEFAULT"], timeout=60)
        for service in SERVICES:
            run(["systemctl", "restart", service + ".service"], timeout=90)


@pytest.fixture(scope="module", params=POLICIES)
def policy(request, bind_zone):
    """Provide the policy under test.

    Without CRYPTO_POLICY, switch to it and restart the services so they pick
    it up. With CRYPTO_POLICY the caller already did that, just check it.
    """
    name = request.param
    if EXPECTED_POLICY:
        assert current_policy() == name
        for service in SERVICES:
            assert service_state(service) == ("active", "running"), service
        return name
    result = run(["update-crypto-policies", "--set", name], timeout=60)
    assert result.returncode == 0, "setting policy %s failed: %s" % (name, result.stdout)
    for service in SERVICES:
        restart_service(service)
    return name


def test_unknown_policy_rejected():
    """A non existent policy is refused and the current one is kept."""
    before = current_policy()
    result = run(["update-crypto-policies", "--set", "FOOBAR"], timeout=30)
    assert result.returncode != 0, result.stdout
    assert "not found" in result.stdout, result.stdout
    assert current_policy() == before


def test_policy_applied(policy):
    """The requested policy is the active one."""
    assert current_policy() == policy


def test_services_running(policy):
    """sshd and named are running after the policy change."""
    for service in SERVICES:
        assert service_state(service) == ("active", "running"), service


def test_bind_dnssec_validation(policy):
    """BIND validates the root DNS signature."""
    result = run(["delv"], timeout=60)
    assert "fully validated" in result.stdout, result.stdout


def test_bind_rndc_status(policy):
    """rndc (crypto key authentication) can talk to named."""
    result = run(["rndc", "status"], timeout=30)
    assert "server is up and running" in result.stdout, result.stdout


def test_bind_local_zone(policy):
    """The local authoritative zone is answered."""
    result = run(["host", "foobar.example.com", "localhost"], timeout=30)
    assert "foobar.example.com has address 1.2.3.4" in result.stdout, result.stdout


def test_gnutls_handshake(policy, tmp_path):
    """gnutls-cli trusts and talks to gnutls-serv with a freshly made CA."""
    def path(name):
        return str(tmp_path / name)

    (tmp_path / "ca.tmpl").write_text(CA_TEMPLATE)
    (tmp_path / "server.tmpl").write_text(SERVER_TEMPLATE)
    steps = (
        (["certtool", "--generate-privkey", "--outfile", path("ca-key.pem")], 120),
        (["certtool", "--generate-self-signed", "--load-privkey", path("ca-key.pem"),
          "--template", path("ca.tmpl"), "--outfile", path("ca.pem")], 120),
        (["certtool", "--generate-privkey", "--outfile", path("server-key.pem")], 120),
        (["certtool", "--generate-certificate", "--load-privkey", path("server-key.pem"),
          "--load-ca-certificate", path("ca.pem"), "--load-ca-privkey", path("ca-key.pem"),
          "--template", path("server.tmpl"), "--outfile", path("server.pem")], 300),
    )
    for cmd, timeout in steps:
        result = run(cmd, timeout=timeout)
        assert result.returncode == 0, "%s failed: %s" % (cmd[:2], result.stdout)

    port = str(free_port())
    server = [
        "gnutls-serv", "-p", port, "--echo", "--x509cafile", path("ca.pem"),
        "--x509keyfile", path("server-key.pem"), "--x509certfile", path("server.pem"),
    ]
    with background(server, path("gnutls-serv.log"), "Echo Server listening"):
        client = ["gnutls-cli", "-p", port, "localhost", "--x509cafile=" + path("ca.pem")]
        output = ""
        for _ in range(5):
            output = run(client, input="helloSUSE\n", timeout=60).stdout
            if "Handshake was completed" in output:
                break
            time.sleep(2)
    assert re.search(
        r"Status: The certificate is trusted.*Handshake was completed.*helloSUSE",
        output, re.DOTALL), output


def test_nss_handshake(policy, tmp_path):
    """The NSS test client gets a page from openssl s_server using a trusted cert."""
    def path(name):
        return str(tmp_path / name)

    nssdb = "sql:" + path("nssdb")
    os.mkdir(path("nssdb"))
    # 4096 bits so the key also satisfies the FUTURE policy
    steps = (
        (["certutil", "-N", "-d", nssdb, "--empty-password"], 60),
        (["openssl", "req", "-new", "-newkey", "rsa:4096", "-x509", "-days", "7", "-nodes",
          "-subj", "/CN=localhost", "-out", path("localhost.pem"),
          "-keyout", path("localhost.key")], 300),
        (["certutil", "-d", nssdb, "-A", "-a", "-i", path("localhost.pem"),
          "-t", "TCP", "-n", "localhost"], 60),
    )
    for cmd, timeout in steps:
        result = run(cmd, timeout=timeout)
        assert result.returncode == 0, "%s failed: %s" % (cmd[:2], result.stdout)

    port = str(free_port())
    server = [
        "openssl", "s_server", "-accept", port, "-cert", path("localhost.pem"),
        "-key", path("localhost.key"), "-www",
    ]
    with background(server, path("s_server.log"), "ACCEPT"):
        client = subprocess.Popen(
            [tstclnt_path(), "-d", nssdb, "-h", "localhost", "-p", port],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            universal_newlines=True,
        )
        try:
            # tstclnt does not exit by itself, so give it some time and stop it
            output, _ = client.communicate("GET / HTTP/1.0\r\n\r\n", timeout=10)
        except subprocess.TimeoutExpired:
            client.kill()
            output, _ = client.communicate()
    assert "HTTP/1.0 200 ok" in output, output
    assert "1 server accepts (SSL_accept())" in output, output
