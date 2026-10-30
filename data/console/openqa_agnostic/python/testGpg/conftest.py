# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
"""Fixtures shared by the GnuPG agnostic tests."""

import os
import shutil
import tempfile

import pytest

from gpg_common import copy_home, fips_target, generate_key, kill_agent


@pytest.fixture(scope="session")
def session_root():
    root = tempfile.mkdtemp(prefix="testGpg-")
    os.chmod(root, 0o700)
    yield root
    shutil.rmtree(root, ignore_errors=True)


@pytest.fixture(scope="session", params=("1024", "2048", "3072", "4096"))
def size_template(request, session_root):
    """A keyring with one RSA key of the requested size."""
    key_size = request.param
    home = os.path.join(session_root, "base-%s" % key_size)
    os.makedirs(home, 0o700)
    result = generate_key(home, key_size)
    if key_size == "1024" and fips_target():
        kill_agent(home)
        shutil.rmtree(home, ignore_errors=True)
        pytest.skip("FIPS rejects 1024-bit keys; see test_fips_1024")
    assert result.returncode == 0, result.stderr
    kill_agent(home)
    yield home
    kill_agent(home)


@pytest.fixture
def key_home(session_root, size_template):
    """An isolated copy of the keyring for one RSA size."""
    dest = tempfile.mkdtemp(prefix="home-", dir=session_root)
    os.rmdir(dest)
    copy_home(size_template, dest)
    yield dest
    kill_agent(dest)
    shutil.rmtree(dest, ignore_errors=True)


@pytest.fixture
def empty_home(session_root):
    """An isolated empty GNUPGHOME."""
    dest = tempfile.mkdtemp(prefix="home-", dir=session_root)
    os.chmod(dest, 0o700)
    yield dest
    kill_agent(dest)
    shutil.rmtree(dest, ignore_errors=True)
