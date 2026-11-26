# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
"""Check the OpenSSH ML-KEM / NIST P-256 hybrid key exchange.

mlkem768nistp256-sha256 combines ML-KEM-768 with ECDH on NIST P-256. SUSE
backports it in jsc#PED-17037 because the BSI TR does not allow the X25519
based hybrids.

The test starts a dedicated sshd in debug mode on a free port of 127.0.0.1.
That sshd reads the system configuration, so the active crypto-policy
applies to the ciphers, MACs and key types. No crypto-policy lists
mlkem768nistp256-sha256, thus KexAlgorithms is set to it on the server and
on the client. The system sshd is not changed.

Standalone use outside openQA::

    mkdir -p /tmp/ssh-pqc/lib
    cp data/openqa_agnostic/lib/helper.sh /tmp/ssh-pqc/lib/
    cp -r data/security/openqa_agnostic/python/testOpenSSHPQCKex /tmp/ssh-pqc/
    cd /tmp/ssh-pqc/testOpenSSHPQCKex
    sudo ./runtest

The run needs root, Python 3.6+, python3-pytest, openssh-clients and
openssh-server.
"""

import os
import shutil
import socket
import subprocess
import tempfile
import time
import uuid

import pytest

KEX = "mlkem768nistp256-sha256"
# ssh and sshd log this line with LogLevel DEBUG1 (ssh -v, sshd -d)
KEX_LINE = "kex: algorithm: " + KEX
# sshd needs an absolute path to re-execute itself
SSHD = "/usr/sbin/sshd"
# known_hosts name of the test sshd, so the entry does not depend on the port
HOST_ALIAS = "openssh-pqc-kex-test"
TIMEOUT = 60


def run(cmd, timeout=TIMEOUT):
    """Run a command without a terminal and return the CompletedProcess."""
    return subprocess.run(
        cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, encoding="utf-8", errors="replace",
        timeout=timeout,
    )


def output(result):
    return "rc %s\nstdout:\n%s\nstderr:\n%s" % (
        result.returncode, result.stdout, result.stderr)


def read(path):
    with open(path, encoding="utf-8", errors="replace") as handle:
        return handle.read()


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def wait_for_text(path, text, proc, timeout=TIMEOUT):
    """Wait until text shows up in the log file of a background process."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if text in read(path):
            return
        if proc.poll() is not None:
            pytest.fail("sshd exited early (rc %s):\n%s" % (proc.returncode, read(path)))
        time.sleep(0.2)
    pytest.fail("'%s' not found in the sshd log within %ss:\n%s" % (text, timeout, read(path)))


def stop(proc):
    if proc.poll() is None:
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()


@pytest.fixture(scope="module")
def ssh_env():
    """Create ECDSA P-384 host and user keys, authorized_keys and known_hosts.

    ECDSA P-384 is allowed by the DEFAULT, BSI and FIPS crypto-policies.
    """
    tmpdir = tempfile.mkdtemp(prefix="openssh_pqc_kex_")
    try:
        env = {"dir": tmpdir}
        for name in ("host_key", "user_key"):
            env[name] = os.path.join(tmpdir, name)
            result = run(["ssh-keygen", "-q", "-t", "ecdsa", "-b", "384",
                          "-N", "", "-f", env[name]])
            assert result.returncode == 0, "ssh-keygen failed:\n" + output(result)
        env["authorized_keys"] = os.path.join(tmpdir, "authorized_keys")
        shutil.copyfile(env["user_key"] + ".pub", env["authorized_keys"])
        os.chmod(env["authorized_keys"], 0o600)
        key_type, key_blob = read(env["host_key"] + ".pub").split()[:2]
        env["known_hosts"] = os.path.join(tmpdir, "known_hosts")
        with open(env["known_hosts"], "w") as handle:
            handle.write("%s %s %s\n" % (HOST_ALIAS, key_type, key_blob))
        yield env
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def sshd_command(env, port):
    """sshd with the system configuration, only for this test."""
    return [
        SSHD, "-p", str(port), "-h", env["host_key"],
        "-o", "ListenAddress=127.0.0.1",
        # sshd removes the PidFile of the system sshd when it gets SIGTERM,
        # also in debug mode
        "-o", "PidFile=none",
        "-o", "KexAlgorithms=" + KEX,
        "-o", "AuthorizedKeysFile=" + env["authorized_keys"],
        # the key files are in a temporary directory
        "-o", "StrictModes=no",
        "-o", "PermitRootLogin=prohibit-password",
        "-o", "PasswordAuthentication=no",
        "-o", "KbdInteractiveAuthentication=no",
    ]


def ssh_command(env, port, *remote_command):
    return [
        "ssh", "-n", "-v", "-p", str(port), "-i", env["user_key"],
        "-o", "IdentitiesOnly=yes",
        "-o", "IdentityAgent=none",
        "-o", "BatchMode=yes",
        "-o", "PreferredAuthentications=publickey",
        "-o", "GSSAPIAuthentication=no",
        "-o", "StrictHostKeyChecking=yes",
        "-o", "HostKeyAlias=" + HOST_ALIAS,
        "-o", "UserKnownHostsFile=" + env["known_hosts"],
        "-o", "GlobalKnownHostsFile=/dev/null",
        "-o", "UpdateHostKeys=no",
        "-o", "ConnectTimeout=20",
        "-o", "KexAlgorithms=" + KEX,
        "root@127.0.0.1",
    ] + list(remote_command)


def test_kex_listed():
    """ssh supports the algorithm. In FIPS mode ssh lists only the
    algorithms that are allowed in FIPS mode."""
    result = run(["ssh", "-Q", "kex"])
    assert result.returncode == 0, output(result)
    assert KEX in result.stdout.split(), (
        "%s is not in 'ssh -Q kex':\n%s" % (KEX, result.stdout))


def test_sshd_accepts_kex(ssh_env):
    """sshd accepts the algorithm as its only KexAlgorithms value. In FIPS
    mode sshd stops if none of the configured algorithms is allowed."""
    # sshd -T does not open the port
    result = run(sshd_command(ssh_env, free_port()) + ["-T"])
    assert result.returncode == 0, "sshd -T failed:\n" + output(result)
    # Newer versions print the keywords in mixed case (KexAlgorithms)
    kex = [line.split(None, 1) for line in result.stdout.splitlines()
           if line.lower().startswith("kexalgorithms ")]
    assert [value for _, value in kex] == [KEX], (
        "sshd -T does not show 'kexalgorithms %s':\n%s" % (KEX, result.stdout))


def test_kex_negotiated(ssh_env):
    """Run a command over ssh and check that both sides negotiated the
    algorithm."""
    log = os.path.join(ssh_env["dir"], "sshd.log")
    token = "openssh-pqc-kex-" + uuid.uuid4().hex
    # get the port just before sshd starts, to keep the race window small
    port = free_port()
    with open(log, "w") as handle:
        # -d: debug mode, sshd serves one connection and then exits
        sshd = subprocess.Popen(
            sshd_command(ssh_env, port) + ["-d", "-e"],
            stdin=subprocess.DEVNULL, stdout=handle, stderr=subprocess.STDOUT,
        )
    try:
        # sshd logs this when it is ready. Do not probe the port: sshd -d
        # would use the probe as its only connection.
        wait_for_text(log, "Server listening on 127.0.0.1 port %d" % port, sshd)
        try:
            client = run(ssh_command(ssh_env, port, "echo", token))
        except subprocess.TimeoutExpired as exc:
            pytest.fail("ssh did not finish within %ss\nssh stderr:\n%s\nsshd log:\n%s"
                        % (exc.timeout, exc.stderr, read(log)))
        if client.returncode == 0:
            # let sshd finish the session and write its last log lines
            try:
                sshd.wait(timeout=10)
            except subprocess.TimeoutExpired:
                pass
    finally:
        stop(sshd)
    server_log = read(log)
    details = "ssh:\n%s\nsshd log:\n%s" % (output(client), server_log)
    assert client.returncode == 0, "ssh failed\n" + details
    assert token in client.stdout, "remote command output is missing\n" + details
    assert KEX_LINE in client.stderr, "ssh did not negotiate %s\n%s" % (KEX, details)
    assert KEX_LINE in server_log, "sshd did not negotiate %s\n%s" % (KEX, details)
