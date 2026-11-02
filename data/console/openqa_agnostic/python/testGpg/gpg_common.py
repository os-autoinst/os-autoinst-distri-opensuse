# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
"""Shared helpers for the GnuPG agnostic tests."""

import os
import shutil
import subprocess
from subprocess import PIPE

PASS = "This_is_a_test_case"
UID = "SUSE Tester"
EMAIL = "user@suse.de"


def run(cmd, input=None, timeout=60, env=None):
    """Run a command and return the CompletedProcess (never raises on rc)."""
    return subprocess.run(
        cmd, input=input, stdout=PIPE, stderr=PIPE,
        universal_newlines=True, timeout=timeout, env=env,
    )


def gpg_env(home):
    env = os.environ.copy()
    env["GNUPGHOME"] = home
    env["LC_ALL"] = "C"
    env["LANG"] = "C"
    return env


def gpg(home, *args, **kwargs):
    """Run gpg with loopback pinentry and the test passphrase."""
    input_data = kwargs.pop("input", None)
    timeout = kwargs.pop("timeout", 60)
    passphrase = kwargs.pop("passphrase", PASS)
    assert not kwargs, "unexpected keyword arguments: %s" % kwargs
    cmd = [
        "gpg", "--batch", "--yes", "--no-tty",
        "--pinentry-mode", "loopback", "--passphrase", passphrase,
    ] + list(args)
    return run(cmd, input=input_data, timeout=timeout, env=gpg_env(home))


def gpgconf(home, *args):
    return run(["gpgconf"] + list(args), env=gpg_env(home))


def kill_agent(home):
    gpgconf(home, "--kill", "all")


def fips_mode():
    """Return True when gpg runs in FIPS mode (kernel or env mode)."""
    result = run(["gpgconf", "--show-versions"], timeout=30)
    if "fips-mode:y" in result.stdout:
        return True
    if "fips-mode:n" in result.stdout:
        return False
    try:
        with open("/proc/sys/crypto/fips_enabled") as fips:
            return fips.read().strip() == "1"
    except OSError:
        return False


def expected_fips():
    """Return the FIPS state set in GPG_EXPECT_FIPS (0/1), or None if unset."""
    value = os.environ.get("GPG_EXPECT_FIPS", "")
    if value not in ("0", "1"):
        return None
    return value == "1"


def fips_target():
    """FIPS state the tests run against: the expected one, else detected."""
    expected = expected_fips()
    return fips_mode() if expected is None else expected


def generate_key(home, key_size, uid=UID, email=EMAIL, passphrase=PASS):
    """Generate an RSA primary key and encryption subkey in batch mode."""
    conf = os.path.join(home, "keygen.conf")
    with open(conf, "w") as keygen:
        keygen.write(
            "Key-Type: RSA\n"
            "Key-Length: %s\n"
            "Subkey-Type: RSA\n"
            "Subkey-Length: %s\n"
            "Name-Real: %s\n"
            "Name-Email: %s\n"
            "Expire-Date: 0\n"
            "Passphrase: %s\n"
            % (key_size, key_size, uid, email, passphrase)
        )
    result = run(
        [
            "gpg", "--batch", "--yes", "--no-tty",
            "--pinentry-mode", "loopback", "--full-generate-key", conf,
        ],
        timeout=120, env=gpg_env(home),
    )
    try:
        os.unlink(conf)
    except OSError:
        pass
    return result


def list_keys(home, *args):
    return gpg(home, "--list-keys", "--with-colons", *args, timeout=30)


def uid_trust(output, email=EMAIL):
    """Return the validity field of the uid matching email."""
    for line in output.splitlines():
        fields = line.split(":")
        if fields[0] == "uid" and email in line:
            return fields[1]
    return None


def key_lengths(output):
    lengths = []
    for line in output.splitlines():
        fields = line.split(":")
        if fields[0] in ("pub", "sub") and fields[2]:
            lengths.append(int(fields[2]))
    return lengths


def copy_home(src, dst):
    """Copy a prepared GNUPGHOME, dropping stale agent sockets and locks."""
    os.makedirs(dst, 0o700)
    for name in os.listdir(src):
        source = os.path.join(src, name)
        if name.startswith("S.") or name.endswith(".lock"):
            continue
        target = os.path.join(dst, name)
        if os.path.isdir(source):
            shutil.copytree(source, target)
        else:
            shutil.copy2(source, target)
    os.chmod(dst, 0o700)
    return dst
