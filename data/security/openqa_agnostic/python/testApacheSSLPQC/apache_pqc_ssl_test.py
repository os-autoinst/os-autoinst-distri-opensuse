import re
import subprocess
from pathlib import Path

import pytest

BASE_DIR = Path(__file__).parent
SERVER = "127.0.0.1:443"

# Apache configuration paths
APACHE_KEY = Path("/etc/apache2/ssl.key/server_mldsa.key")
APACHE_CRT = Path("/etc/apache2/ssl.crt/server_mldsa.crt")
VHOST_CONF = BASE_DIR / "pqc-ssl.conf"
APACHE_VHOST = Path("/etc/apache2/vhosts.d/pqc-ssl.conf")

# all post-quantum ML-DSA signature algorithms
MLDSA_VARIANTS = ["mldsa44", "mldsa65", "mldsa87"]
# all post-quantum ML-KEM key exchange algorithms
MLKEM_VARIANTS = ["mlkem512", "mlkem768", "mlkem1024"]


@pytest.fixture(scope="session", autouse=True)
def setup_apache():
    """Deploy the virtual host configuration, ensure SSL flag is set in
    sysconfig and stop firewalld."""

    # copy virtual host configuration
    subprocess.run(["cp", str(VHOST_CONF), str(APACHE_VHOST)], check=True)

    # make sure SSL is present (enabled) in Apache server flags
    sysconfig = Path("/etc/sysconfig/apache2")
    content = sysconfig.read_text()
    match = re.search(r'^APACHE_SERVER_FLAGS="([^"]*)"', content, re.MULTILINE)
    flags = match.group(1) if match else ""
    if "SSL" not in flags.split():
        new_flags = (flags + " SSL").strip()
        subprocess.run(
            [
                "sed", "-i",
                f's/^APACHE_SERVER_FLAGS=.*/APACHE_SERVER_FLAGS="{new_flags}"/',
                str(sysconfig),
            ],
            check=True,
        )

    # stop firewall
    subprocess.run(["systemctl", "stop", "firewalld"], check=True)
    result = subprocess.run(
        ["systemctl", "is-active", "firewalld"],
        capture_output=True, text=True,
    )
    assert result.stdout.strip() == "inactive", (
        f"firewalld is still running: {result.stdout.strip()}"
    )


@pytest.fixture(scope="session", params=MLDSA_VARIANTS)
def mldsa(request):
    """Generate ML-DSA key and self-signed certificate for the given variant,
    deploy them to Apache directories, restart Apache and verify it is
    listening on port 443. Returns the variant name and certificate path."""
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

    # copy key/certificate to relevant Apache directories
    subprocess.run(["cp", str(key), str(APACHE_KEY)], check=True)
    subprocess.run(["cp", str(crt), str(APACHE_CRT)], check=True)

    # (re)start Apache and make sure it's listening
    subprocess.run(["systemctl", "restart", "apache2"], check=True)
    result = subprocess.run(
        ["ss", "-tlnp"],
        capture_output=True, text=True, check=True,
    )
    assert ":443" in result.stdout, (
        f"Apache is not listening on port 443:\n{result.stdout}"
    )
    return variant, crt


def _s_client_output(groups: str, cafile: Path) -> str:
    """Run openssl s_client against the server restricted to the given KEM group
    and send a minimal HTTP/1.0 GET. Returns combined stdout and stderr."""
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
    line)."""
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
    """Verify the server returns HTTP 200 over a PQC TLS connection using curl.
    curl -v verbose output (sent to stderr) is checked for 'HTTP/1.1 200 OK'.
    We use -k (aka --insecure) option with curl because cert is self-signed"""
    result = subprocess.run(
        ["curl", "-k", "-v", "--curves", groups, "https://localhost:443"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
        timeout=10,
    )
    assert "HTTP/1.1 200 OK" in result.stderr, (
        f"Expected 'HTTP/1.1 200 OK' in curl output:\n{result.stderr}"
    )
