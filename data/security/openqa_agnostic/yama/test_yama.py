# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

import subprocess
import pytest

USERNAME = "bernhard"
PID_FILE = "/tmp/yama_test.pid"


def _run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def test_ptrace_scope_is_one():
    """yama.ptrace_scope must be 1 for ptrace confinement to be active."""
    with open("/proc/sys/kernel/yama/ptrace_scope") as f:
        assert f.read().strip() == "1", "yama.ptrace_scope must be 1"


@pytest.fixture
def unprivileged_user():
    # best-effort cleanup of any leftover from a previous run
    _run(["pkill", "-9", "-u", USERNAME])
    _run(["userdel", "-rf", USERNAME])
    subprocess.run(["useradd", "-m", USERNAME], check=True)
    try:
        yield USERNAME
    finally:
        _run(["pkill", "-9", "-u", USERNAME])
        _run(["userdel", "-rf", USERNAME])
        _run(["rm", "-f", PID_FILE])


def test_ptrace_denied_for_unprivileged(unprivileged_user):
    """A non-privileged user must not be able to ptrace its own process."""
    # Start a long-lived process owned by the unprivileged user
    subprocess.run(
        ["su", "-", unprivileged_user, "-c",
         f"nohup sleep 300 >/dev/null 2>&1 & echo $! > {PID_FILE}"],
        check=True,
    )
    with open(PID_FILE) as f:
        pid = int(f.read().strip())

    # Attempt to strace it as the same (non-root) user.
    # When yama denies ptrace, strace exits immediately. The timeout is a
    # safety net so the test fails fast instead of hanging the whole job if
    # ptrace is unexpectedly allowed and strace attaches to the sleeping pid.
    result = _run(
        ["su", "-", unprivileged_user, "-c", f"strace -p {pid}"],
        timeout=30,
    )
    combined = result.stdout + result.stderr
    assert "Operation not permitted" in combined, (
        f"Expected ptrace to be denied by yama, got:\n{combined}"
    )


if __name__ == "__main__":
    pytest.main([__file__])
