#!/usr/bin/python3
"""
Functional tests for salt-master and salt-minion on localhost.

Tests cover package installation verification, salt-call local operations,
master-minion loopback communication (key acceptance, test.ping, command
execution, grains, state application), and clean service lifecycle.

Inspired by:
    saltstack/salt  tests/pytests/pkg/integration/test_salt_minion.py
    saltstack/salt  tests/pytests/pkg/integration/test_salt_key.py
    saltstack/salt  tests/pytests/pkg/integration/test_salt_state_file.py
    saltstack/salt  tests/pytests/pkg/integration/test_salt_exec.py
    saltstack/salt  tests/pytests/pkg/integration/test_salt_pillar.py

Unlike upstream tests which use pytest-salt-factories to manage daemon
lifecycle, these tests drive installed salt packages directly via systemctl
and CLI commands -- no extra dependencies beyond pytest.

Tests require root privileges. The test runner (openQA .pm module or
manual invocation) must install salt-master and salt-minion beforehand.

Usage:
    sudo python3 -m pytest test_salt.py -v
    sudo python3 -m pytest test_salt.py -v -x   # stop on first failure

References:
    openQA legacy test   tests/console/salt.pm
    Upstream Salt tests  tests/pytests/pkg/integration/
"""

import json
import os
import re
import shutil
import subprocess
import textwrap
import time
from subprocess import PIPE

import pytest


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

def run(cmd, check=True, timeout=30, input_data=None):
    """Run a command and return CompletedProcess."""
    return subprocess.run(
        cmd, input=input_data, stdout=PIPE, stderr=PIPE,
        universal_newlines=True, check=check, timeout=timeout,
    )


def systemctl(action, service, timeout=30):
    """Run systemctl action on a service."""
    return run(["systemctl", action, service], check=False, timeout=timeout)


def is_service_active(service):
    """Check whether a systemd service is active."""
    result = systemctl("is-active", service)
    return result.stdout.strip() == "active"


def wait_for_condition(func, description, timeout=60, interval=5):
    """Poll func() until it returns True or timeout expires.

    Returns True if the condition was met, raises AssertionError otherwise.
    """
    deadline = time.monotonic() + timeout
    last_err = None
    while time.monotonic() < deadline:
        try:
            if func():
                return True
        except Exception as exc:
            last_err = exc
        time.sleep(interval)
    msg = f"Timed out waiting for: {description} (timeout={timeout}s)"
    if last_err:
        msg += f" -- last error: {last_err}"
    raise AssertionError(msg)


def salt_cmd(args, timeout=30):
    """Run a salt CLI command and return CompletedProcess.

    Wrapper around 'salt' with common defaults: --out=json, no color.
    """
    cmd = ["salt", "--out=json", "--no-color"] + args
    return run(cmd, check=False, timeout=timeout)


def salt_call(args, timeout=30):
    """Run salt-call with --local and return CompletedProcess."""
    cmd = ["salt-call", "--local", "--out=json", "--no-color"] + args
    return run(cmd, check=False, timeout=timeout)


def salt_key(args, timeout=15):
    """Run salt-key and return CompletedProcess."""
    cmd = ["salt-key", "--no-color"] + args
    return run(cmd, check=False, timeout=timeout)


def get_minion_id():
    """Read the minion id from /etc/salt/minion_id or fall back to hostname."""
    minion_conf = "/etc/salt/minion"
    minion_id_file = "/etc/salt/minion_id"
    # After first start, salt writes minion_id
    if os.path.exists(minion_id_file):
        with open(minion_id_file) as f:
            mid = f.read().strip()
            if mid:
                return mid
    # Fall back to hostname
    result = run(["hostname", "-s"], check=False)
    return result.stdout.strip()


# ---------------------------------------------------------------------------
# constants
# ---------------------------------------------------------------------------

MINION_CONF = "/etc/salt/minion"
MINION_CONF_BACKUP = "/etc/salt/minion.test-backup"
MINION_ID_FILE = "/etc/salt/minion_id"
MASTER_STATE_DIR = "/srv/salt"
MASTER_PILLAR_DIR = "/srv/pillar"

# Test state file content
TEST_STATE_NAME = "agnostic_test"
TEST_STATE_SLS = textwrap.dedent("""\
    test_file_managed:
      file.managed:
        - name: /tmp/salt_agnostic_test_file
        - contents: "salt agnostic test ok"
""")

# Test pillar content
TEST_PILLAR_NAME = "agnostic_test"
TEST_PILLAR_SLS = textwrap.dedent("""\
    agnostic_test_key: agnostic_test_value
""")
TEST_PILLAR_TOP = textwrap.dedent("""\
    base:
      '*':
        - agnostic_test
""")


# ---------------------------------------------------------------------------
# fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def require_root():
    """Skip all tests if not running as root."""
    if os.geteuid() != 0:
        pytest.skip("test requires root privileges")


@pytest.fixture(scope="session")
def salt_master_service():
    """Start salt-master for the test session, stop on teardown.

    Yields the service name. On teardown, stops the service and
    removes cached keys/state.
    """
    # Ensure master is stopped before we start (clean slate)
    subprocess.run(["systemctl", "stop", "salt-master"], check=False,
                    timeout=30, stdout=PIPE, stderr=PIPE)
    subprocess.run(["systemctl", "stop", "salt-minion"], check=False,
                    timeout=30, stdout=PIPE, stderr=PIPE)
    # Remove stale keys so the minion must re-authenticate
    for d in ["/etc/salt/pki/master/minions",
              "/etc/salt/pki/master/minions_pre",
              "/etc/salt/pki/minion"]:
        if os.path.isdir(d):
            for f in os.listdir(d):
                fp = os.path.join(d, f)
                if os.path.isfile(fp):
                    os.unlink(fp)
    time.sleep(1)

    # Start the master
    result = subprocess.run(["systemctl", "start", "salt-master"],
                             check=True, timeout=60, stdout=PIPE, stderr=PIPE)

    # Wait until the master's runner subsystem is responsive
    def master_ready():
        try:
            r = subprocess.run(["salt-run", "test.arg", "ready",
                                "--out=json", "--no-color"],
                               check=False, timeout=15,
                               stdout=PIPE, stderr=PIPE,
                               universal_newlines=True)
            return r.returncode == 0
        except subprocess.TimeoutExpired:
            return False

    deadline = time.monotonic() + 120
    ready = False
    while time.monotonic() < deadline:
        if master_ready():
            ready = True
            break
        time.sleep(2)
    assert ready, "salt-master did not become responsive within 120s"

    yield "salt-master"

    # Teardown: stop master
    subprocess.run(["systemctl", "stop", "salt-master"], check=False,
                    timeout=60, stdout=PIPE, stderr=PIPE)


@pytest.fixture(scope="session")
def salt_minion_configured():
    """Configure salt-minion to use localhost as master.

    Backs up the original config and restores it on teardown.
    Also cleans up the minion_id file and PKI keys.
    """
    # Backup original config
    if os.path.exists(MINION_CONF):
        shutil.copy2(MINION_CONF, MINION_CONF_BACKUP)

    # Configure minion to connect to localhost
    with open(MINION_CONF) as f:
        content = f.read()
    content = re.sub(r'^#?master:\s*.*$', 'master: localhost',
                     content, count=1, flags=re.MULTILINE)
    with open(MINION_CONF, "w") as f:
        f.write(content)

    yield

    # Restore original config
    if os.path.exists(MINION_CONF_BACKUP):
        shutil.copy2(MINION_CONF_BACKUP, MINION_CONF)
        os.unlink(MINION_CONF_BACKUP)

    # Clean up minion_id so next test run gets a fresh identity
    if os.path.exists(MINION_ID_FILE):
        os.unlink(MINION_ID_FILE)


@pytest.fixture(scope="session")
def salt_minion_service(salt_master_service, salt_minion_configured):
    """Start salt-minion for the test session, stop on teardown.

    Depends on salt_master_service and salt_minion_configured.
    Yields the minion id.
    """
    # Ensure minion is stopped before we start
    subprocess.run(["systemctl", "stop", "salt-minion"], check=False,
                    timeout=30, stdout=PIPE, stderr=PIPE)
    time.sleep(1)

    # Start the minion
    subprocess.run(["systemctl", "start", "salt-minion"],
                    check=True, timeout=60, stdout=PIPE, stderr=PIPE)

    # Give the minion a moment to connect and send its auth request
    time.sleep(3)

    yield

    # Teardown: stop minion
    subprocess.run(["systemctl", "stop", "salt-minion"], check=False,
                    timeout=60, stdout=PIPE, stderr=PIPE)


@pytest.fixture(scope="session")
def salt_keys_accepted(salt_minion_service):
    """Wait for the minion key to appear and accept it.

    Yields the minion id after key acceptance.
    """
    minion_id = get_minion_id()

    # Wait for the key to appear in unaccepted list
    def key_pending():
        r = salt_key(["-l", "unaccepted", "--out=json"], timeout=10)
        if r.returncode != 0:
            return False
        try:
            data = json.loads(r.stdout)
        except (json.JSONDecodeError, ValueError):
            return False
        # The key name varies: "minions_pre" or "Unaccepted Keys"
        for key in data:
            if isinstance(data[key], list) and len(data[key]) > 0:
                return True
        return False

    wait_for_condition(key_pending, "minion key to appear in pending list",
                       timeout=60, interval=3)

    # Accept all pending keys
    result = salt_key(["-A", "-y"])
    assert result.returncode == 0, f"salt-key accept failed: {result.stderr}"

    # Wait until the minion is responsive
    def minion_responds():
        r = salt_cmd(["*", "test.ping", "--timeout=10"], timeout=20)
        if r.returncode != 0:
            return False
        try:
            data = json.loads(r.stdout)
        except (json.JSONDecodeError, ValueError):
            return False
        # Check any minion returned True
        return any(v is True for v in data.values())

    wait_for_condition(minion_responds, "minion to respond to test.ping",
                       timeout=90, interval=5)

    yield minion_id


@pytest.fixture(scope="session")
def salt_state_tree(salt_keys_accepted):
    """Create a test state tree and pillar tree.

    Sets up a minimal SLS file and pillar for state/pillar tests.
    Cleans up on teardown.
    """
    state_dir = MASTER_STATE_DIR
    pillar_dir = MASTER_PILLAR_DIR

    os.makedirs(state_dir, exist_ok=True)
    os.makedirs(pillar_dir, exist_ok=True)

    # Write the test state
    state_file = os.path.join(state_dir, f"{TEST_STATE_NAME}.sls")
    with open(state_file, "w") as f:
        f.write(TEST_STATE_SLS)

    # Write the test pillar
    pillar_file = os.path.join(pillar_dir, f"{TEST_PILLAR_NAME}.sls")
    pillar_top = os.path.join(pillar_dir, "top.sls")

    # Back up existing pillar top.sls if present
    pillar_top_backup = None
    if os.path.exists(pillar_top):
        pillar_top_backup = pillar_top + ".test-backup"
        shutil.copy2(pillar_top, pillar_top_backup)

    with open(pillar_file, "w") as f:
        f.write(TEST_PILLAR_SLS)
    with open(pillar_top, "w") as f:
        f.write(TEST_PILLAR_TOP)

    yield

    # Cleanup
    for path in [state_file, pillar_file]:
        if os.path.exists(path):
            os.unlink(path)

    # Remove the test output file
    test_file = "/tmp/salt_agnostic_test_file"
    if os.path.exists(test_file):
        os.unlink(test_file)

    if pillar_top_backup:
        shutil.copy2(pillar_top_backup, pillar_top)
        os.unlink(pillar_top_backup)
    elif os.path.exists(pillar_top):
        os.unlink(pillar_top)


# ---------------------------------------------------------------------------
# Test classes
# ---------------------------------------------------------------------------

class TestPackageBasics:
    """Verify that salt packages are installed and report valid versions."""

    def test_salt_master_installed(self):
        """salt-master binary is present in PATH."""
        result = run(["which", "salt-master"], check=False)
        assert result.returncode == 0, "salt-master not found in PATH"

    def test_salt_minion_installed(self):
        """salt-minion binary is present in PATH."""
        result = run(["which", "salt-minion"], check=False)
        assert result.returncode == 0, "salt-minion not found in PATH"

    def test_salt_master_version(self):
        """salt-master --version returns a valid version string."""
        result = run(["salt-master", "--version"])
        assert "salt" in result.stdout.lower(), \
            f"unexpected version output: {result.stdout}"
        # Version should contain a number pattern like 3006.0 or 3007.1
        assert re.search(r'\d{4}', result.stdout), \
            f"no version number found: {result.stdout}"

    def test_salt_minion_version(self):
        """salt-minion --version returns a valid version string."""
        result = run(["salt-minion", "--version"])
        assert "salt" in result.stdout.lower(), \
            f"unexpected version output: {result.stdout}"
        assert re.search(r'\d{4}', result.stdout), \
            f"no version number found: {result.stdout}"

    def test_salt_version_consistency(self):
        """salt-master and salt-minion report the same version."""
        master_ver = run(["salt-master", "--version"]).stdout.strip()
        minion_ver = run(["salt-minion", "--version"]).stdout.strip()
        # Extract version numbers (e.g., "3006.0")
        m_match = re.search(r'(\d{4}\.\d+)', master_ver)
        n_match = re.search(r'(\d{4}\.\d+)', minion_ver)
        assert m_match and n_match, \
            f"cannot parse versions: master={master_ver}, minion={minion_ver}"
        assert m_match.group(1) == n_match.group(1), \
            f"version mismatch: master={m_match.group(1)}, minion={n_match.group(1)}"


class TestSaltCallLocal:
    """Test salt-call --local operations (no master/minion needed).

    These tests validate that the salt Python runtime, modules, and
    local configuration work correctly. They run without starting
    any daemons.
    """

    def test_local_test_ping(self):
        """salt-call --local test.ping returns True."""
        result = salt_call(["test.ping"])
        assert result.returncode == 0, \
            f"salt-call test.ping failed: {result.stderr}"
        data = json.loads(result.stdout)
        assert data.get("local") is True, \
            f"expected True, got: {data}"

    def test_local_grains_os(self):
        """salt-call --local grains.item os returns a valid OS name."""
        result = salt_call(["grains.item", "os"])
        assert result.returncode == 0, \
            f"salt-call grains.item os failed: {result.stderr}"
        data = json.loads(result.stdout)
        os_name = data.get("local", {}).get("os", "")
        assert os_name, f"empty os grain: {data}"
        # Should be something like "openSUSE Tumbleweed", "SLES", "Leap"
        assert isinstance(os_name, str) and len(os_name) > 0

    def test_local_grains_kernel(self):
        """salt-call --local grains.item kernel returns 'Linux'."""
        result = salt_call(["grains.item", "kernel"])
        assert result.returncode == 0, \
            f"salt-call grains.item kernel failed: {result.stderr}"
        data = json.loads(result.stdout)
        kernel = data.get("local", {}).get("kernel", "")
        assert kernel == "Linux", f"expected 'Linux', got: {kernel}"

    def test_local_cmd_run(self):
        """salt-call --local cmd.run executes a command."""
        result = salt_call(["cmd.run", "echo salt_agnostic_test_marker"])
        assert result.returncode == 0, \
            f"salt-call cmd.run failed: {result.stderr}"
        data = json.loads(result.stdout)
        output = data.get("local", "")
        assert "salt_agnostic_test_marker" in output, \
            f"expected marker in output: {data}"

    def test_local_status_uptime(self):
        """salt-call --local status.uptime returns uptime info."""
        result = salt_call(["status.uptime"])
        assert result.returncode == 0, \
            f"salt-call status.uptime failed: {result.stderr}"
        data = json.loads(result.stdout)
        uptime = data.get("local", "")
        # Should contain some uptime string
        assert uptime, f"empty uptime: {data}"


class TestMasterService:
    """Test salt-master service lifecycle."""

    def test_master_is_active(self, salt_master_service):
        """salt-master service is running after start."""
        assert is_service_active("salt-master"), \
            "salt-master is not active"

    def test_master_process_exists(self, salt_master_service):
        """salt-master process is present in the process table."""
        result = run(["pgrep", "-f", "salt-master"], check=False)
        assert result.returncode == 0, \
            "no salt-master process found"


class TestMinionService:
    """Test salt-minion service lifecycle."""

    def test_minion_configured_localhost(self, salt_minion_configured):
        """Minion config has master set to localhost."""
        with open(MINION_CONF) as f:
            content = f.read()
        assert re.search(r'^master:\s*localhost\s*$', content,
                         re.MULTILINE), \
            "minion config does not have 'master: localhost'"

    def test_minion_is_active(self, salt_minion_service):
        """salt-minion service is running after start."""
        assert is_service_active("salt-minion"), \
            "salt-minion is not active"

    def test_minion_process_exists(self, salt_minion_service):
        """salt-minion process is present in the process table."""
        result = run(["pgrep", "-f", "salt-minion"], check=False)
        assert result.returncode == 0, \
            "no salt-minion process found"


class TestKeyManagement:
    """Test salt key acceptance and listing."""

    def test_key_accepted(self, salt_keys_accepted):
        """The minion key is in the accepted keys list."""
        result = salt_key(["-l", "accepted", "--out=json"])
        assert result.returncode == 0, \
            f"salt-key list failed: {result.stderr}"
        data = json.loads(result.stdout)
        # Find the list of accepted keys (key name varies by salt version)
        accepted = []
        for key, val in data.items():
            if isinstance(val, list):
                accepted.extend(val)
        assert len(accepted) > 0, \
            f"no accepted keys found: {data}"

    def test_no_pending_keys(self, salt_keys_accepted):
        """No keys are left in the pending (unaccepted) state."""
        result = salt_key(["-l", "unaccepted", "--out=json"])
        assert result.returncode == 0
        data = json.loads(result.stdout)
        pending = []
        for key, val in data.items():
            if isinstance(val, list):
                pending.extend(val)
        assert len(pending) == 0, \
            f"unexpected pending keys: {pending}"

    def test_key_finger(self, salt_keys_accepted):
        """salt-key -f returns a fingerprint for the accepted minion."""
        minion_id = salt_keys_accepted
        result = salt_key(["-f", minion_id, "--out=json"])
        assert result.returncode == 0, \
            f"salt-key finger failed: {result.stderr}"
        data = json.loads(result.stdout)
        # The output should contain the minion id somewhere in the data
        flat = json.dumps(data)
        assert minion_id in flat or len(data) > 0, \
            f"no fingerprint data for {minion_id}: {data}"


class TestMasterMinionCommunication:
    """Test basic master-minion communication via salt CLI.

    These tests exercise the core master->minion command execution
    path that the legacy salt.pm test validates with test.ping.
    We go further by also testing cmd.run, grains, and state apply.
    """

    def test_ping(self, salt_keys_accepted):
        """salt '*' test.ping returns True for the minion."""
        result = salt_cmd(["*", "test.ping", "--timeout=15"])
        assert result.returncode == 0, \
            f"test.ping failed: {result.stderr}"
        data = json.loads(result.stdout)
        assert any(v is True for v in data.values()), \
            f"no minion responded True: {data}"

    def test_ping_by_minion_id(self, salt_keys_accepted):
        """Ping using the specific minion id."""
        minion_id = salt_keys_accepted
        result = salt_cmd([minion_id, "test.ping", "--timeout=15"])
        assert result.returncode == 0, \
            f"test.ping by id failed: {result.stderr}"
        data = json.loads(result.stdout)
        assert data.get(minion_id) is True, \
            f"minion {minion_id} did not respond True: {data}"

    def test_cmd_run_uname(self, salt_keys_accepted):
        """salt '*' cmd.run 'uname -s' returns 'Linux'."""
        result = salt_cmd(["*", "cmd.run", "uname -s", "--timeout=15"])
        assert result.returncode == 0, \
            f"cmd.run failed: {result.stderr}"
        data = json.loads(result.stdout)
        assert any("Linux" in str(v) for v in data.values()), \
            f"no minion returned Linux: {data}"

    def test_cmd_run_hostname(self, salt_keys_accepted):
        """salt '*' cmd.run 'hostname' returns a non-empty string."""
        result = salt_cmd(["*", "cmd.run", "hostname", "--timeout=15"])
        assert result.returncode == 0, \
            f"cmd.run hostname failed: {result.stderr}"
        data = json.loads(result.stdout)
        assert any(len(str(v).strip()) > 0 for v in data.values()), \
            f"empty hostname response: {data}"

    def test_grains_os(self, salt_keys_accepted):
        """salt '*' grains.item os returns a valid OS name."""
        result = salt_cmd(["*", "grains.item", "os", "--timeout=15"])
        assert result.returncode == 0, \
            f"grains.item os failed: {result.stderr}"
        data = json.loads(result.stdout)
        # Each minion returns {"os": "..."} -- extract any value
        for minion_data in data.values():
            if isinstance(minion_data, dict):
                os_val = minion_data.get("os", "")
                assert len(os_val) > 0, f"empty os grain: {minion_data}"

    def test_grains_kernel(self, salt_keys_accepted):
        """salt '*' grains.item kernel returns 'Linux'."""
        result = salt_cmd(["*", "grains.item", "kernel", "--timeout=15"])
        assert result.returncode == 0, \
            f"grains.item kernel failed: {result.stderr}"
        data = json.loads(result.stdout)
        for minion_data in data.values():
            if isinstance(minion_data, dict):
                assert minion_data.get("kernel") == "Linux", \
                    f"expected Linux kernel grain: {minion_data}"

    def test_salt_run_manage_status(self, salt_keys_accepted):
        """salt-run manage.status shows the minion as up."""
        result = run(["salt-run", "--out=json", "--no-color",
                       "manage.status", "--timeout=15"],
                      check=False, timeout=30)
        assert result.returncode == 0, \
            f"manage.status failed: {result.stderr}"
        data = json.loads(result.stdout)
        up_list = data.get("up", [])
        assert len(up_list) > 0, f"no minions up: {data}"


class TestStateApply:
    """Test applying a salt state via master-minion communication."""

    def test_state_apply(self, salt_state_tree, salt_keys_accepted):
        """Apply a test state and verify the managed file is created."""
        result = salt_cmd(["*", "state.apply", TEST_STATE_NAME,
                           "--timeout=30"], timeout=60)
        assert result.returncode == 0, \
            f"state.apply failed: {result.stderr}"
        data = json.loads(result.stdout)
        # Verify at least one minion reported success
        for minion_id, states in data.items():
            if isinstance(states, dict):
                for state_id, state_result in states.items():
                    assert state_result.get("result") is True, \
                        f"state {state_id} failed on {minion_id}: {state_result}"

    def test_state_file_exists(self, salt_state_tree, salt_keys_accepted):
        """The file created by the test state exists with correct content."""
        test_file = "/tmp/salt_agnostic_test_file"
        assert os.path.exists(test_file), \
            f"{test_file} was not created by state.apply"
        with open(test_file) as f:
            content = f.read().strip()
        assert content == "salt agnostic test ok", \
            f"unexpected content: {content}"


class TestPillar:
    """Test pillar data delivery to minion."""

    def test_pillar_items(self, salt_state_tree, salt_keys_accepted):
        """salt '*' pillar.items returns our test pillar data."""
        # Refresh pillar first to pick up our new pillar file
        salt_cmd(["*", "saltutil.refresh_pillar", "--timeout=15"],
                 timeout=30)
        time.sleep(2)

        result = salt_cmd(["*", "pillar.items", "--timeout=15"])
        assert result.returncode == 0, \
            f"pillar.items failed: {result.stderr}"
        data = json.loads(result.stdout)
        # Check that our test key appears in at least one minion's pillar
        found = False
        for minion_id, pillar_data in data.items():
            if isinstance(pillar_data, dict):
                if pillar_data.get("agnostic_test_key") == "agnostic_test_value":
                    found = True
                    break
        assert found, f"test pillar key not found in pillar data: {data}"

    def test_pillar_get(self, salt_state_tree, salt_keys_accepted):
        """salt '*' pillar.get returns our specific test value."""
        result = salt_cmd(["*", "pillar.get", "agnostic_test_key",
                           "--timeout=15"])
        assert result.returncode == 0, \
            f"pillar.get failed: {result.stderr}"
        data = json.loads(result.stdout)
        assert any(v == "agnostic_test_value" for v in data.values()), \
            f"test pillar value not found: {data}"


class TestServiceCleanup:
    """Verify that salt services can be stopped cleanly.

    The session-scoped fixtures also stop the services on teardown, but
    with check=False -- they do not assert on the result. These tests
    explicitly verify that systemctl stop returns 0 and the process is
    gone. Runs last by CPython source-order guarantee.
    """

    def test_stop_minion(self, salt_keys_accepted):
        """salt-minion service stops cleanly."""
        result = systemctl("stop", "salt-minion", timeout=60)
        assert result.returncode == 0, \
            f"failed to stop salt-minion: {result.stderr}"
        # Give it a moment
        time.sleep(1)
        assert not is_service_active("salt-minion"), \
            "salt-minion is still active after stop"

    def test_stop_master(self, salt_master_service):
        """salt-master service stops cleanly."""
        result = systemctl("stop", "salt-master", timeout=60)
        assert result.returncode == 0, \
            f"failed to stop salt-master: {result.stderr}"
        time.sleep(1)
        assert not is_service_active("salt-master"), \
            "salt-master is still active after stop"
