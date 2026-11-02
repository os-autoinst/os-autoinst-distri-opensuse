import re
import subprocess
import time
from pathlib import Path

import pytest

BASE_DIR = Path(__file__).parent
PORT = 443
SERVER = f"127.0.0.1:{PORT}"
# seconds to wait for nginx to listen after a restart
LISTEN_TIMEOUT = 10

# nginx configuration paths
NGINX_SSL_DIR = Path("/etc/nginx/ssl")
NGINX_KEY = NGINX_SSL_DIR / "server_mldsa.key"
NGINX_CRT = NGINX_SSL_DIR / "server_mldsa.crt"
VHOST_CONF = BASE_DIR / "pqc-ssl.conf"
NGINX_VHOST = Path("/etc/nginx/vhosts.d/pqc-ssl.conf")

# test page served by nginx, nginx returns 403 for a directory without an index page
TEST_PAGE = Path("/srv/www/htdocs/pqc_nginx.html")
TEST_PAGE_TEXT = "nginx post-quantum TLS test page"

# all post-quantum ML-DSA signature algorithms
MLDSA_VARIANTS = ["mldsa44", "mldsa65", "mldsa87"]
# all post-quantum ML-KEM key exchange algorithms
MLKEM_VARIANTS = ["mlkem512", "mlkem768", "mlkem1024"]


@pytest.fixture(scope="session", autouse=True)
def setup_nginx():
    """Create the nginx SSL directory, deploy the virtual host configuration
    and write the test page.

    The firewall is not stopped: all the connections go through the loopback
    interface, which firewalld always accepts.
    """

    NGINX_SSL_DIR.mkdir(parents=True, exist_ok=True)

    # copy virtual host configuration
    subprocess.run(["cp", str(VHOST_CONF), str(NGINX_VHOST)], check=True)

    # write the test page
    TEST_PAGE.write_text(f"<html>{TEST_PAGE_TEXT}</html>\n")


@pytest.fixture(scope="session", params=MLDSA_VARIANTS)
def mldsa(request):
    """Generate (if not already present) ML-DSA key and self-signed certificate
    for the given variant, deploy them to nginx directories, restart nginx and
    verify it is listening on port 443.
    Returns the variant name and certificate path.

    :param request: (pytest.FixtureRequest) pytest request object; request.param
                    holds the ML-DSA variant for this instance, eg. 'mldsa65'
    :return: (tuple[str, Path]) ML-DSA variant name and path to its self-signed certificate
    """
    variant = request.param
    key = BASE_DIR / f"server_{variant}.key"
    crt = BASE_DIR / f"server_{variant}.crt"

    # generate ML-DSA key
    if not key.exists():
        subprocess.run(
            ["openssl", "genpkey", "-algorithm", variant, "-out", str(key)],
            check=True,
        )

    # generate ML-DSA self-signed certificate
    if not crt.exists():
        subprocess.run(
            [
                "openssl", "req", "-new", "-x509",
                "-key", str(key), "-out", str(crt),
                "-days", "365",
                "-subj", "/C=US/ST=Washington/L=Redmond/O=PQTest/CN=pqtest.local",
                "-addext", "keyUsage=digitalSignature",
                "-addext", "extendedKeyUsage=serverAuth",
            ],
            check=True,
        )

    # copy key/certificate to relevant nginx directory
    subprocess.run(["cp", str(key), str(NGINX_KEY)], check=True)
    subprocess.run(["cp", str(crt), str(NGINX_CRT)], check=True)

    # (re)start nginx and make sure it's listening.
    # Do not run 'nginx -t' from the test: in this unconfined shell it creates
    # /run/nginx.pid with the var_run_t SELinux type, and then the confined
    # nginx service cannot open it. The nginx service runs 'nginx -t' itself
    # before it starts, so a configuration or key load error shows in the journal.
    result = subprocess.run(
        ["systemctl", "restart", "nginx"], capture_output=True, text=True
    )
    if result.returncode != 0:
        journal = subprocess.run(
            ["journalctl", "-u", "nginx", "-n", "20", "--no-pager"],
            capture_output=True, text=True,
        )
        pytest.fail(
            f"nginx failed to (re)start:\n{result.stderr}\n{journal.stdout}"
        )
    if not _wait_for_listen_port():
        result = subprocess.run(["ss", "-tlnp"], capture_output=True, text=True)
        pytest.fail(
            f"nginx is not listening on port {PORT} after {LISTEN_TIMEOUT}s:\n"
            f"{result.stdout}"
        )
    return variant, crt


def _wait_for_listen_port() -> bool:
    """Wait until a socket listens on the server port.
    The nginx service is 'Type=simple': 'systemctl restart' returns before
    nginx has bound its sockets, so a single check right after the restart fails.

    :return: (bool) True if the port is listening before LISTEN_TIMEOUT expires
    """
    deadline = time.monotonic() + LISTEN_TIMEOUT
    while time.monotonic() < deadline:
        result = subprocess.run(
            ["ss", "-Htln", "sport", "=", f":{PORT}"],
            capture_output=True, text=True, check=True,
        )
        if result.stdout.strip():
            return True
        time.sleep(0.2)
    return False


def _s_client_output(groups: str, cafile: Path) -> str:
    """Run openssl s_client against the server restricted to the given KEM group
    and send a minimal HTTP/1.0 GET over TLS.

    :param groups: (str) ML-KEM group to restrict the key exchange to, eg. 'mlkem768'
    :param cafile: (Path) CA certificate used to verify the server certificate
    :return: (str) combined stdout and stderr of openssl s_client
    """
    result = subprocess.run(
        [
            "openssl", "s_client",
            "-connect", SERVER,
            "-groups", groups,
            "-CAfile", str(cafile),
            "-servername", "pqtest.local",
        ],
        input="GET / HTTP/1.0\r\nHost: pqtest.local\r\n\r\n",
        capture_output=True,
        text=True,
        timeout=10,
    )
    return result.stdout + result.stderr


@pytest.mark.parametrize("groups", MLKEM_VARIANTS)
def test_pqc_tls_handshake(mldsa, groups):
    """Verify the TLS handshake uses the expected ML-KEM group for key exchange
    (checked in 'Negotiated TLS1.3 group' line) and the expected ML-DSA variant
    for the server certificate signature (checked in 'Peer signature type'
    line).

    :param mldsa: (tuple[str, Path]) ML-DSA variant name and certificate path from the mldsa fixture
    :param groups: (str) ML-KEM group to use for the key exchange
    """
    variant, crt = mldsa
    output = _s_client_output(groups, crt)
    neg_group = next(
        (l for l in output.splitlines() if "Negotiated TLS1.3 group" in l), ""
    )
    assert groups.upper() in neg_group or groups in neg_group, (
        f"Expected {groups} in 'Negotiated TLS1.3 group' line:\n{neg_group}"
    )
    peer_sig = next(
        (l for l in output.splitlines() if "Peer signature type" in l), ""
    )
    label = f"ML-DSA-{variant[len('mldsa'):]}"
    assert variant in peer_sig.lower() or label in peer_sig, (
        f"Expected {label} in 'Peer signature type' line:\n{peer_sig}"
    )


@pytest.mark.parametrize("groups", MLKEM_VARIANTS)
def test_pqc_curl_https_request(mldsa, groups):
    """Verify the server returns the test page with HTTP 200 over a PQC TLS
    connection using curl. curl -v verbose output (sent to stderr) is checked
    for the HTTP 200 status line and the page body (sent to stdout) for the test
    page text. The HTTP version is not checked: nginx can negotiate HTTP/2 via
    ALPN if the distribution nginx.conf enables it.
    We use -k (aka --insecure) option with curl because cert is self-signed

    :param mldsa: (tuple[str, Path]) mldsa fixture, requested so nginx is set up with the ML-DSA certificate
    :param groups: (str) ML-KEM group passed to curl --curves
    """
    result = subprocess.run(
        ["curl", "-k", "-v", "--curves", groups, f"https://{SERVER}/{TEST_PAGE.name}"],
        capture_output=True,
        text=True,
        timeout=10,
    )
    assert re.search(r"^< HTTP/[\d.]+ 200\b", result.stderr, re.MULTILINE), (
        f"Expected HTTP 200 status line in curl output:\n{result.stderr}"
    )
    assert TEST_PAGE_TEXT in result.stdout, (
        f"Expected '{TEST_PAGE_TEXT}' in page body:\n{result.stdout}"
    )
