# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
"""Functional tests for GnuPG (gpg).

Ported from tests/console/gpg.pm. The passphrase is supplied through
``--pinentry-mode loopback`` instead of driving pinentry-curses with
needles, so the test works on the text console.

Standalone use outside openQA::

    mkdir -p /tmp/gpg-agnostic/lib
    cp data/openqa_agnostic/lib/helper.sh /tmp/gpg-agnostic/lib/
    cp -r data/console/openqa_agnostic/python/testGpg /tmp/gpg-agnostic/
    cd /tmp/gpg-agnostic/testGpg
    sudo ./runtest

The run needs root (enforced by runtest), Python 3.6+, python3-pytest and
gpg2 (gpg, gpgconf, gpg-connect-agent). It does not read openQA variables
or needles. Set GPG_EXPECT_FIPS=1 or 0 to fail when the FIPS state of the
system differs; without it the FIPS state is detected.

Every test uses its own temporary GNUPGHOME. The RSA keys are generated
once per key size in a session template and copied per test. Because the
fixtures start a fresh agent in the temporary home, FIPS env-mode
variables exported by the shell are inherited and no stale agent from an
earlier module is reused.
"""

import os

import pytest

from gpg_common import (
    EMAIL, expected_fips, fips_mode, fips_target, generate_key, gpg,
    key_lengths, kill_agent, list_keys, run, gpg_env, uid_trust,
)

def test_fips_state():
    """gpg runs in the FIPS state given by GPG_EXPECT_FIPS."""
    expected = expected_fips()
    if expected is None:
        pytest.skip("GPG_EXPECT_FIPS is not set")
    assert fips_mode() == expected, "gpg FIPS mode is %s, expected %s" % (
        fips_mode(), expected)


def test_fips_1024(empty_home):
    """FIPS mode rejects 1024-bit RSA keys."""
    if not fips_target():
        pytest.skip("not running in FIPS mode")
    result = generate_key(empty_home, "1024")
    assert result.returncode != 0, "FIPS accepted a 1024-bit RSA key"
    assert "Invalid value" in result.stderr, result.stderr


def test_keygen(size_template):
    """The generated key is listed with the requested size and trust."""
    listing = list_keys(size_template)
    assert listing.returncode == 0, listing.stderr
    assert uid_trust(listing.stdout) == "u", listing.stdout
    key_size = int(os.path.basename(size_template).split("-")[-1])
    assert key_lengths(listing.stdout) == [key_size, key_size], listing.stdout


def test_encrypt_decrypt(key_home, tmp_path):
    """A file encrypted to the key decrypts to its original content."""
    source = tmp_path / "foo.txt"
    source.write_text("foo test content\n")
    encrypted = str(source) + ".gpg"
    result = gpg(key_home, "-r", EMAIL, "-o", encrypted, "-e", str(source))
    assert result.returncode == 0, result.stderr
    assert os.path.exists(encrypted)
    result = gpg(key_home, "-u", EMAIL, "-d", encrypted)
    assert result.returncode == 0, result.stderr
    assert result.stdout == "foo test content\n"


def test_clearsign_verify(key_home, tmp_path):
    """A clear-signed file verifies and keeps the plaintext."""
    source = tmp_path / "clearsign.txt"
    source.write_text("clear signature content\n")
    signed = str(source) + ".asc"
    result = gpg(key_home, "-u", EMAIL, "--clearsign", "-o", signed, str(source))
    assert result.returncode == 0, result.stderr
    with open(signed) as handle:
        assert "BEGIN PGP SIGNED MESSAGE" in handle.read()
    result = gpg(key_home, "--verify", signed)
    assert result.returncode == 0, result.stderr


def test_agent_restart(key_home, tmp_path):
    """Reloading or killing gpg-agent drops the cached passphrase."""
    source = tmp_path / "agent.txt"
    content = "agent restart content\n"
    source.write_text(content)
    encrypted = str(source) + ".gpg"
    result = gpg(key_home, "-r", EMAIL, "-o", encrypted, "-e", str(source))
    assert result.returncode == 0, result.stderr

    result = gpg(key_home, "-d", encrypted)
    assert result.returncode == 0, result.stderr
    assert result.stdout == content
    # The agent caches the passphrase, so a wrong one is not even asked for
    result = gpg(key_home, "-d", encrypted, passphrase="wrong")
    assert result.returncode == 0, result.stderr

    reload_agent = run(
        ["gpg-connect-agent", "RELOADAGENT", "/bye"], env=gpg_env(key_home), timeout=30)
    assert reload_agent.returncode == 0, reload_agent.stderr
    assert gpg(key_home, "-d", encrypted, passphrase="wrong").returncode != 0, \
        "the passphrase cache survived RELOADAGENT"
    result = gpg(key_home, "-d", encrypted)
    assert result.returncode == 0, result.stderr
    assert result.stdout == content

    kill_agent(key_home)
    assert gpg(key_home, "-d", encrypted, passphrase="wrong").returncode != 0, \
        "the passphrase cache survived gpgconf --kill"
    result = gpg(key_home, "-d", encrypted)
    assert result.returncode == 0, result.stderr
    assert result.stdout == content
