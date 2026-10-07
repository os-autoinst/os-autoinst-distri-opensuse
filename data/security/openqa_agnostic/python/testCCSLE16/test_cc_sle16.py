"""
SLES EAL4+ SLE 16 Common Criteria certification verification.

Runs the check/apply scripts from the certification repo
(data/security/sle16_cc/ in os-autoinst-distri-opensuse).

Phase control: CC_PHASE env var, set by the .pm wrapper before each run.
  pre  - run check (record initial status) then run apply
  post - run check only, assert it exits 0 (apply has been applied + rebooted)
"""
import os
import subprocess

import pytest

CC_PHASE = os.environ.get("CC_PHASE", "pre")
REPO_DIR = os.path.expanduser("~/certification-sles-eal4-16.0")
CHECK_SCRIPT = os.path.join(REPO_DIR, "check")
APPLY_SCRIPT = os.path.join(REPO_DIR, "apply")


def _run(script, label):
    """Run a repo script, print full output, return the CompletedProcess."""
    print("=== {} ===".format(label))
    result = subprocess.run(
        [script],
        cwd=REPO_DIR,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        universal_newlines=True,
    )
    print(result.stdout)
    print("=== {} exit code: {} ===".format(label, result.returncode))
    return result


# ---------------------------------------------------------------------------
# pre phase: check current status, then apply
# ---------------------------------------------------------------------------

@pytest.mark.pre
def test_check_pre_cc_apply():
    """Step 2: run 'check' and record initial CC status (exit 0 expected)."""
    result = _run(CHECK_SCRIPT, "check (pre-apply)")
    assert result.returncode == 0, (
        "'check' failed before apply (exit {}). "
        "Output:\n{}".format(result.returncode, result.stdout)
    )


@pytest.mark.pre
def test_apply_cc():
    """Step 3: run 'apply' to configure the system for CC compliance.

    Exit code 2 is not a failure: the configuration is applied correctly,
    but a reboot is required before it is fully in effect.
    """
    result = _run(APPLY_SCRIPT, "apply")
    assert result.returncode in (0, 2), (
        "'apply' failed (exit {}). "
        "Output:\n{}".format(result.returncode, result.stdout)
    )


# ---------------------------------------------------------------------------
# post phase: verify check succeeds after reboot
# ---------------------------------------------------------------------------

@pytest.mark.post
def test_check_post_cc_apply():
    """Step 4: run 'check' after reboot, assert CC compliance is in place."""
    result = _run(CHECK_SCRIPT, "check (post-apply)")
    assert result.returncode == 0, (
        "'check' failed after apply+reboot (exit {}). "
        "Output:\n{}".format(result.returncode, result.stdout)
    )
