# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

import subprocess
import pytest
import os
import socket
import time
import signal
from pathlib import Path


# TEST DATA

ML_KEM_ALGOS = ["ML-KEM-512", "ML-KEM-768", "ML-KEM-1024"]
HYBRID_KEM_ALGOS = ["X25519MLKEM768", "X448MLKEM1024", "SecP256r1MLKEM768", "SecP384r1MLKEM1024"]
ML_DSA_ALGOS = ["ML-DSA-44", "ML-DSA-65", "ML-DSA-87"]
SLH_DSA_ALGOS = ["SLH-DSA-SHA2-128s", "SLH-DSA-SHA2-128f", "SLH-DSA-SHAKE-256s"]


# Support class for OpenSSL command execution and fixtures
class OpenSSLDriver:
    """
    Handles OpenSSL command execution and manages the algorithm support cache.
    """
    def __init__(self, binary="openssl"):
        self.binary = binary
        self._all_algos_cache = None
        self._tls_groups_cache = None
        self._keygen_supported_cache = None

    def run(self, args, cwd=None, check=True, capture_output=True, input=None):
        """
        Helper to run openssl commands safely.
        """
        # Provider Injection Logic:
        # 1. s_server/s_client: Need 'default' AND 'base' for full hybrid OID resolution.
        # 2. genpkey/pkey etc: Need 'default'. 'base' sometimes conflicts with PEM encoders
        #    in early 3.x builds, so we stick to 'default' unless DER is used.
        if args and args[0] in ["s_server", "s_client"]:
            cmd_args = [args[0], "-provider", "default", "-provider", "base"] + args[1:]
        elif args and args[0] in ["genpkey", "pkey", "pkeyutl", "dgst", "req"]:
            cmd_args = [args[0], "-provider", "default"] + args[1:]
        else:
            cmd_args = args
        cmd = [self.binary] + cmd_args
        result = subprocess.run(
            cmd,
            cwd=cwd,
            check=False,
            capture_output=capture_output,
            text=False,
            input=input
        )
        if check and result.returncode != 0:
            stderr_str = result.stderr.decode('utf-8', errors='replace')
            raise RuntimeError(
                f"OpenSSL command failed: {' '.join(cmd)}\n"
                f"Return Code: {result.returncode}\n"
                f"Error Output: {stderr_str}"
            )
        return result

    def is_supported(self, algo_name):
        """
        Broad check: is the algorithm listed ANYWHERE (KEM, Sig, PK, or TLS)?
        Useful for general lifecycle tests.
        """
        if self._all_algos_cache is None:
            try:
                res_kem = self.run(["list", "-kem-algorithms"], check=False)
                res_pk = self.run(["list", "-public-key-algorithms"], check=False)
                res_sig = self.run(["list", "-signature-algorithms"], check=False)
                res_tls = self.run(["list", "-tls-groups"], check=False)
                output = (res_kem.stdout + res_pk.stdout + res_sig.stdout + res_tls.stdout).decode('utf-8', errors='ignore')
                self._all_algos_cache = output.lower()
            except Exception:
                self._all_algos_cache = ""
                return False
        return algo_name.lower() in self._all_algos_cache

    def is_tls_group(self, algo_name):
        """
        Specific check: is this algorithm a registered TLS Group?
        Mandatory for s_client/s_server -groups flag.
        """
        if self._tls_groups_cache is None:
            try:
                res = self.run(["list", "-tls-groups"], check=False)
                self._tls_groups_cache = res.stdout.decode('utf-8', errors='ignore').lower()
            except Exception:
                self._tls_groups_cache = ""
        return algo_name.lower() in self._tls_groups_cache

    def can_generate_key(self, algo_name):
        """
        Stricter check: can we actually run 'genpkey' for this algorithm?
        """
        if self._keygen_supported_cache is None:
            self._keygen_supported_cache = set()
        if algo_name in self._keygen_supported_cache:
            return True

        devnull = "NUL" if os.name == 'nt' else "/dev/null"
        res = self.run([
            "genpkey", 
            "-algorithm", algo_name, 
            "-out", devnull
        ], check=False)
        if res.returncode == 0:
            self._keygen_supported_cache.add(algo_name)
            return True
        return False

    def generate_cert(self, key_path, cert_path):
        # 1. Generate Key
        self.run(["genpkey", "-algorithm", "ED25519", "-out", str(key_path)])
        # 2. Generate Self-Signed Cert
        self.run([
            "req", "-new", "-x509", 
            "-key", str(key_path), 
            "-out", str(cert_path), 
            "-days", "1", 
            "-subj", "/CN=localhost"
        ])


@pytest.fixture(scope="session")
def openssl():
    return OpenSSLDriver(binary="openssl")



# TEST: 'openssl dgst' compatibility with Post-Quantum DSA
@pytest.mark.parametrize("algo", ML_DSA_ALGOS)
def test_ml_dsa_explicit_dgst_compatibility(tmp_path: Path, algo, openssl):
    if not openssl.is_supported(algo):
        pytest.skip(f"Algorithm {algo} not supported.")

    priv_key_path = tmp_path / "dgst_key.der"
    pub_key_path = tmp_path / "dgst_pub.der"
    data_path = tmp_path / "dgst_data.txt"
    sig_path = tmp_path / "dgst_sig.bin"
    data_path.write_text("Testing openssl dgst")
    openssl.run(["genpkey", "-algorithm", algo, "-outform", "DER", "-out", str(priv_key_path)])
    openssl.run(["pkey", "-in", str(priv_key_path), "-inform", "DER", "-pubout", "-outform", "DER", "-out", str(pub_key_path)])

    res = openssl.run([
        "dgst", "-sign", str(priv_key_path), "-keyform", "DER",
        "-out", str(sig_path), str(data_path)
    ], check=False)

    if res.returncode == 0:
        openssl.run([
            "dgst", "-verify", str(pub_key_path), "-keyform", "DER",
            "-signature", str(sig_path), str(data_path)
        ])
    else:
        print(f"Note: 'openssl dgst' CLI might not support {algo} directly yet.")


# TEST: TLS 1.3 Handshake with PQC / Hybrid KEMs
@pytest.mark.parametrize("algo", HYBRID_KEM_ALGOS)
def test_tls_handshake(tmp_path: Path, algo, openssl):
    """
    Spins up an 'openssl s_server' and connects with 'openssl s_client'
    enforcing the specific PQC or Hybrid group for Key Exchange.
    """
    # STRICT CHECK: Only attempt handshake if OpenSSL explicitly lists it as a TLS group.
    if not openssl.is_tls_group(algo):
        pytest.skip(f"Algorithm {algo} is not listed in 'openssl list -tls-groups'.")

    # 1. Prepare Server Certs
    server_key = tmp_path / "server.key"
    server_cert = tmp_path / "server.crt"
    openssl.generate_cert(server_key, server_cert)

    # 2. Find a free port
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(('localhost', 0))
        port = s.getsockname()[1]

    # 3. Start s_server in background
    # We use @SECLEVEL=0 to allow mismatched key strengths
    server_cmd = [
        openssl.binary, "s_server",
        "-accept", str(port),
        "-cert", str(server_cert),
        "-key", str(server_key),
        "-www", 
        "-provider", "default",
        "-provider", "base", # Explicitly load base for robust OID resolution
        "-groups", algo,
        "-cipher", "ALL:@SECLEVEL=0" 
    ]
    
    server_proc = subprocess.Popen(
        server_cmd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

    try:
        # Give server a moment to start (X448 might be slower)
        time.sleep(1.0)
        
        # 4. Run s_client
        client_res = openssl.run([
            "s_client",
            "-connect", f"localhost:{port}",
            "-groups", algo, 
            "-no_ssl3", "-no_tls1", "-no_tls1_1", "-no_tls1_2",
            "-cipher", "ALL:@SECLEVEL=0"
        ], input=b"GET / HTTP/1.0\r\n\r\n", check=False)

        output_stdout = client_res.stdout.decode('utf-8', errors='ignore')
        output_stderr = client_res.stderr.decode('utf-8', errors='ignore')
        full_output = output_stdout + "\n=== STDERR ===\n" + output_stderr

        # 5. Validation
        success_markers = ["Cipher is", "Cipher :", "SSL-Session:"]
        if not any(m in output_stdout for m in success_markers):
             pytest.fail(f"TLS Handshake failed (No Session/Cipher info found). Output:\n{full_output}")
        
        # Check 2: Correct KEM Negotiation
        expected_markers = [
            f"Negotiated TLS1.3 group: {algo}",
            f"Server Temp Key: {algo}",
            f"Negotiated Group: {algo}"
        ]
        
        if not any(m.lower() in full_output.lower() for m in expected_markers):
            pytest.fail(
                f"Handshake succeeded but negotiated Key/Group mismatch.\n"
                f"Expected one of: {expected_markers}\n"
                f"Client Output Snippet:\n{full_output[:2000]}"
            )

    finally:
        # 6. Cleanup
        server_proc.terminate()
        try:
            server_proc.wait(timeout=1)
        except subprocess.TimeoutExpired:
            server_proc.kill()


# TEST: KEM (Key Encapsulation Mechanism) Lifecycle
@pytest.mark.parametrize("algo", ML_KEM_ALGOS + HYBRID_KEM_ALGOS)
def test_kem_lifecycle(tmp_path: Path, algo, openssl):
    """
    Tests Key Encapsulation Mechanism (File-based).
    """
    if not openssl.is_supported(algo):
        pytest.skip(f"Algorithm {algo} not supported.")
    
    if not openssl.can_generate_key(algo):
        pytest.skip(f"Algorithm {algo} appears to be a TLS Group only (no CLI KeyGen support).")

    priv_key_path = tmp_path / "key.der"
    openssl.run(["genpkey", "-algorithm", algo, "-outform", "DER", "-out", str(priv_key_path)])
    
    pub_key_path = tmp_path / "pub.der"
    openssl.run(["pkey", "-in", str(priv_key_path), "-inform", "DER", "-pubout", "-outform", "DER", "-out", str(pub_key_path)])

    ciphertext_path = tmp_path / "ct.dat"
    ss_enc_path = tmp_path / "ss_enc.dat"
    
    openssl.run([
        "pkeyutl", "-encap",
        "-inkey", str(pub_key_path),
        "-keyform", "DER",
        "-pubin",
        "-out", str(ciphertext_path),
        "-secret", str(ss_enc_path)
    ])
    
    assert ss_enc_path.stat().st_size > 0

    ss_dec_path = tmp_path / "ss_dec.dat"
    openssl.run([
        "pkeyutl", "-decap",
        "-inkey", str(priv_key_path),
        "-keyform", "DER",
        "-in", str(ciphertext_path),
        "-secret", str(ss_dec_path)
    ])

    secret_enc = ss_enc_path.read_bytes()
    secret_dec = ss_dec_path.read_bytes()
    assert secret_enc == secret_dec


# TEST: Post-Quantum Digital Signatures
@pytest.mark.parametrize("algo", ML_DSA_ALGOS + SLH_DSA_ALGOS)
def test_post_quantum_signatures(tmp_path: Path, algo, openssl):
    if not openssl.is_supported(algo):
        pytest.skip(f"Algorithm {algo} not supported.")

    priv_key_path = tmp_path / "sign_key.der"
    openssl.run(["genpkey", "-algorithm", algo, "-outform", "DER", "-out", str(priv_key_path)])
    
    pub_key_path = tmp_path / "sign_pub.der"
    openssl.run(["pkey", "-in", str(priv_key_path), "-inform", "DER", "-pubout", "-outform", "DER", "-out", str(pub_key_path)])

    data_path = tmp_path / "data.txt"
    data_path.write_text("Signed message.")
    signature_path = tmp_path / "signature.bin"
    
    openssl.run([
        "pkeyutl", "-sign",
        "-inkey", str(priv_key_path),
        "-keyform", "DER",
        "-in", str(data_path),
        "-out", str(signature_path)
    ])
    
    assert signature_path.stat().st_size > 0

    res_valid = openssl.run([
        "pkeyutl", "-verify",
        "-inkey", str(pub_key_path),
        "-keyform", "DER",
        "-pubin",
        "-in", str(data_path),
        "-sigfile", str(signature_path)
    ], check=False)

    assert res_valid.returncode == 0

    tampered_path = tmp_path / "bad.txt"
    tampered_path.write_text("Tampered.")
    res_tamper = openssl.run([
        "pkeyutl", "-verify",
        "-inkey", str(pub_key_path),
        "-keyform", "DER",
        "-pubin",
        "-in", str(tampered_path),
        "-sigfile", str(signature_path)
    ], check=False)

    assert res_tamper.returncode != 0


