# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

import os
import re
import subprocess
import pytest

# C source files, living in data/security/ and compiled binary names
SRC_FIPS_CHECK = "libgcrypt-fips-check.c"
BIN_FIPS_CHECK = "libgcrypt-fips-test"
SRC_SIGN_VERIFY = "libgcrypt-sign-verify.c"
BIN_SIGN_VERIFY = "libgcrypt-sign-verify"


def _run(cmd, **kw):
    """Run a shell command capturing stdout and stderr as text.

    Returns:
        subprocess.CompletedProcess: The result with stdout/stderr as strings.
    """
    return subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
        **kw
    )


@pytest.fixture(scope="session")
def fips_env():
    """Check whether the system runs in FIPS crypto-policy-only mode.

    Returns:
        bool: True if FIPS_ENV_MODE=1 is set in the environment.
    """
    return os.environ.get("FIPS_ENV_MODE") == "1"


@pytest.fixture(scope="session")
def fips_enabled():
    """Check whether kernel-level FIPS mode is expected.

    Returns:
        bool: True if FIPS_ENABLED=1 is set in the environment.
    """
    return os.environ.get("FIPS_ENABLED") == "1"


@pytest.fixture(scope="session")
def fips_status():
    """Query the system FIPS status via fips-mode-setup --check.

    Returns:
        str: Combined stdout and stderr from fips-mode-setup.
    """
    result = _run(["fips-mode-setup", "--check"])
    return result.stdout + result.stderr


@pytest.fixture(scope="session")
def compiled_fips_check(tmpdir_factory):
    """Compile the libgcrypt FIPS-check C program into a temporary directory.

    Locates libgcrypt-fips-check.c from the repo data/security/ tree or
    falls back to /tmp/ (where the openQA wrapper downloads it).

    :param tmpdir_factory: pytest tmpdir_factory fixture
    :return: str Absolute path to the compiled binary.
    """
    build_dir = str(tmpdir_factory.mktemp("fips_check"))
    src = os.path.join(build_dir, SRC_FIPS_CHECK)
    binary = os.path.join(build_dir, BIN_FIPS_CHECK)
    data_dir = os.path.join(os.path.dirname(__file__), "..", "..", "..", SRC_FIPS_CHECK)
    if not os.path.isfile(data_dir):
        data_dir = "/tmp/{}".format(SRC_FIPS_CHECK)
    subprocess.run(["cp", data_dir, src], check=True)
    subprocess.run(
        ["gcc", "-std=c11", src, "-lgcrypt", "-lgpg-error", "-o", binary],
        check=True,
    )
    return binary


@pytest.fixture(scope="session")
def compiled_sign_verify(tmpdir_factory):
    """Compile the libgcrypt sign/verify C program into a temporary directory.

    Locates libgcrypt-sign-verify.c from the repo data/security/ tree or
    falls back to /tmp/ (where the openQA wrapper downloads it).

    :param tmpdir_factory: pytest tmpdir_factory fixture
    :return: str Absolute path to the compiled binary.
    """
    build_dir = str(tmpdir_factory.mktemp("sign_verify"))
    src = os.path.join(build_dir, SRC_SIGN_VERIFY)
    binary = os.path.join(build_dir, BIN_SIGN_VERIFY)
    data_dir = os.path.join(os.path.dirname(__file__), "..", "..", "..", SRC_SIGN_VERIFY)
    if not os.path.isfile(data_dir):
        data_dir = "/tmp/{}".format(SRC_SIGN_VERIFY)
    subprocess.run(["cp", data_dir, src], check=True)
    subprocess.run(
        ["gcc", "-std=c11", src, "-lgcrypt", "-lgpg-error", "-o", binary],
        check=True,
    )
    return binary


class TestFIPSModeDetection:
    def test_fips_env_mode(self, fips_env, fips_status):
        """Verify FIPS crypto-policy mode is active without kernel FIPS."""
        if not fips_env:
            pytest.skip("Not running in FIPS_ENV_MODE")
        assert "FIPS mode is enabled." not in fips_status, \
            "Kernel FIPS unexpectedly enabled while running in FIPS_ENV_MODE"
        assert "The current crypto policy (FIPS) is based on the FIPS policy." in fips_status, \
            "ENV FIPS should be enabled, but it is not"

    def test_fips_kernel_mode(self, fips_env, fips_status):
        """Verify kernel-level FIPS mode is enabled."""
        if fips_env:
            pytest.skip("Running in FIPS_ENV_MODE, skipping kernel FIPS check")
        assert "FIPS mode is enabled." in fips_status, \
            f"Kernel FIPS expected but not enabled:\n{fips_status}"


class TestLibgcryptFIPSCheck:
    def test_fips_mode_reported(self, compiled_fips_check):
        """Verify libgcrypt reports FIPS mode as enabled in its TAP output."""
        result = _run([compiled_fips_check])
        assert result.returncode == 0, f"FIPS check binary failed:\n{result.stderr}"
        assert re.search(r"^# FIPS Mode:\s*Enabled$", result.stdout, re.MULTILINE), \
            "System is in FIPS mode, but libgcrypt reports FIPS disabled"

    def test_no_runtime_failures(self, compiled_fips_check):
        """Verify all TAP test lines pass with no 'not ok' results."""
        result = _run([compiled_fips_check])
        assert result.returncode == 0, f"FIPS check binary failed:\n{result.stderr}"
        assert not re.search(r"^not ok\b", result.stdout, re.MULTILINE), \
            f"libgcrypt runtime self-test failed:\n{result.stdout}"


@pytest.fixture(scope="session")
def sign_verify_output(compiled_sign_verify):
    """Run the sign/verify binary once and cache its stdout for all tests.

    Returns:
        str: Stdout from the libgcrypt-sign-verify binary.
    """
    result = _run([compiled_sign_verify])
    return result.stdout


class TestSignVerify:
    def test_rsa(self, sign_verify_output):
        """Verify RSA sign/verify succeeds."""
        assert re.search(r"RSA:\s*OK", sign_verify_output), \
            f"RSA sign/verify failed:\n{sign_verify_output}"

    def test_ecdsa(self, sign_verify_output):
        """Verify ECDSA sign/verify succeeds."""
        assert re.search(r"ECDSA:\s*OK", sign_verify_output), \
            f"ECDSA sign/verify failed:\n{sign_verify_output}"

    def test_ml_dsa(self, sign_verify_output, fips_enabled):
        """Verify ML-DSA sign/verify succeeds, or skip if blocked in FIPS mode."""
        if re.search(r"ML-DSA:\s*OK", sign_verify_output):
            return
        if fips_enabled:
            pytest.skip("ML-DSA not available or blocked (expected in FIPS)")
        else:
            pytest.fail("ML-DSA sign/verify not working in non-FIPS system")


if __name__ == "__main__":
    pytest.main([__file__])
