#!/usr/bin/python3
"""
Functional tests for the sudo package.

Ported from Debian's autopkgtest suite for sudo, adapted for openSUSE/SUSE.
Tests require root privileges and create/remove temporary users and files.

Usage:
    sudo python3 -m pytest test_sudo.py -v
    sudo python3 test_sudo.py

Original Debian tests:
    01-getroot              -> TestGetRoot
    02-1003969-audit        -> TestAuditNoResolve
    03-1126085-sudoersd     -> TestSudoersD
"""

import os
import pwd
import grp
import shutil
import subprocess
from subprocess import PIPE
import tempfile
import textwrap
import pytest





# -- helpers --

def run(cmd, input=None, check=True, timeout=30):
    """Run a command and return CompletedProcess."""
    return subprocess.run(
        cmd, input=input, stdout=PIPE, stderr=PIPE, universal_newlines=True,
        check=check, timeout=timeout,
    )


def user_exists(name):
    try:
        pwd.getpwnam(name)
        return True
    except KeyError:
        return False


def group_exists(name):
    try:
        grp.getgrnam(name)
        return True
    except KeyError:
        return False


def ensure_group(name):
    """Create a system group if it does not exist."""
    if not group_exists(name):
        run(["groupadd", "-r", name])


def create_user(name, password, groups=None):
    """Create a test user with a home directory and password."""
    if user_exists(name):
        remove_user(name)
    if groups:
        for g in groups:
            ensure_group(g)
    cmd = ["useradd", "-m", "-s", "/bin/bash", name]
    run(cmd)
    run(["chpasswd"], input=f"{name}:{password}\n")
    if groups:
        for g in groups:
            run(["usermod", "-aG", g, name])


def remove_user(name):
    """Remove a test user and their home directory."""
    if not user_exists(name):
        return
    # Kill any processes owned by the user first
    run(["pkill", "-u", name], check=False)
    run(["userdel", "-rf", name], check=False)


def sudo_as_user(username, password, target_user="root", timeout=10):
    """Run 'sudo -u <target> --stdin id -u' as the given user.

    Returns (returncode, stdout, stderr).
    Raises RuntimeError if su itself fails (user does not exist, etc).
    """
    inner_cmd = f"echo '{password}' | sudo -u {target_user} --stdin id -u"
    result = subprocess.run(
        ["su", "-", username, "-c", inner_cmd],
        stdout=PIPE, stderr=PIPE, universal_newlines=True, timeout=timeout,
    )
    # Detect su failure (user doesn't exist, shell broken) vs sudo failure
    if result.returncode != 0 and "No passwd entry" in result.stderr:
        raise RuntimeError(f"su failed for user {username}: {result.stderr}")
    return result.returncode, result.stdout.strip(), result.stderr.strip()


def sudo_clear_timestamp():
    """Clear sudo credential cache for the current user (root).

    Note: this only affects the root user's cache. Test users created
    by create_user() start with no cached credentials because they are
    freshly created. This function is called as a defensive measure.
    """
    run(["sudo", "-K"], check=False)


def install_sudoers_rule(filename, content):
    """Write a sudoers rule to /etc/sudoers.d/."""
    path = f"/etc/sudoers.d/{filename}"
    with open(path, "w") as f:
        f.write(content)
    os.chmod(path, 0o440)
    os.chown(path, 0, 0)
    return path


def remove_sudoers_rule(filename):
    """Remove a sudoers rule from /etc/sudoers.d/."""
    path = f"/etc/sudoers.d/{filename}"
    if os.path.exists(path):
        os.unlink(path)


# -- fixtures --

@pytest.fixture(autouse=True)
def require_root():
    if os.geteuid() != 0:
        pytest.skip("test requires root privileges")


@pytest.fixture
def test_users():
    """Create and clean up test users."""
    created = []

    def _make(name, password, groups=None):
        create_user(name, password, groups)
        created.append(name)
        return name

    yield _make

    for name in created:
        remove_user(name)


@pytest.fixture
def sudoers_rules():
    """Create and clean up sudoers.d rules."""
    created = []

    def _make(filename, content):
        path = install_sudoers_rule(filename, content)
        created.append(filename)
        return path

    yield _make

    for filename in created:
        remove_sudoers_rule(filename)


def _is_read_only(path):
    """Check if a file's filesystem is read-only."""
    try:
        fd = os.open(path, os.O_WRONLY | os.O_APPEND)
        os.close(fd)
        return False
    except OSError:
        return True


@pytest.fixture
def isolated_sudoers():
    """Temporarily replace the active sudoers with a minimal config.

    The default SUSE sudoers has 'ALL ALL=(ALL) ALL' with targetpw,
    which interferes with tests that need to verify access denial.

    sudo reads "Sudoers path: /etc/sudoers:/usr/etc/sudoers" (first
    found wins). On normal systems, the fixture backs up and replaces
    the active file. On immutable/transactional systems where
    /usr/etc is read-only, it creates /etc/sudoers as an override
    (which takes precedence) and removes it on teardown.
    """
    minimal = textwrap.dedent("""\
        # Temporary minimal sudoers for testing
        Defaults env_reset
        Defaults secure_path="/usr/sbin:/usr/bin:/sbin:/bin"
        root ALL=(ALL:ALL) ALL
        @includedir /etc/sudoers.d
    """)

    etc_sudoers = "/etc/sudoers"
    usr_sudoers = "/usr/etc/sudoers"

    # Case 1: /etc/sudoers exists and is writable (normal system with admin override)
    if os.path.exists(etc_sudoers) and not _is_read_only(etc_sudoers):
        backup = etc_sudoers + ".test-backup"
        shutil.copy2(etc_sudoers, backup)
        try:
            with open(etc_sudoers, "w") as f:
                f.write(minimal)
            os.chmod(etc_sudoers, 0o440)
            yield
        finally:
            shutil.copy2(backup, etc_sudoers)
            os.chmod(etc_sudoers, 0o440)
            os.unlink(backup)
        return

    # Case 2: only /usr/etc/sudoers exists and is writable (normal Tumbleweed)
    if os.path.exists(usr_sudoers) and not _is_read_only(usr_sudoers):
        backup = usr_sudoers + ".test-backup"
        shutil.copy2(usr_sudoers, backup)
        try:
            with open(usr_sudoers, "w") as f:
                f.write(minimal)
            os.chmod(usr_sudoers, 0o440)
            yield
        finally:
            shutil.copy2(backup, usr_sudoers)
            os.chmod(usr_sudoers, 0o440)
            os.unlink(backup)
        return

    # Case 3: /usr/etc/sudoers exists but is read-only (immutable system)
    # Create /etc/sudoers as override; it takes precedence over /usr/etc
    if os.path.exists(usr_sudoers):
        created = not os.path.exists(etc_sudoers)
        if not created:
            backup = etc_sudoers + ".test-backup"
            shutil.copy2(etc_sudoers, backup)
        try:
            with open(etc_sudoers, "w") as f:
                f.write(minimal)
            os.chmod(etc_sudoers, 0o440)
            yield
        finally:
            if created:
                os.unlink(etc_sudoers)
            else:
                shutil.copy2(backup, etc_sudoers)
                os.chmod(etc_sudoers, 0o440)
                os.unlink(backup)
        return

    pytest.skip("cannot find sudoers file")


# -- Test 01: getroot --
# Ported from Debian 01-getroot
# Tests basic sudo authentication: correct password, wrong password,
# non-member rejection.

class TestGetRoot:
    """Test sudo authentication with user's own password.

    Sets up a self-contained sudoers policy that disables the SUSE default
    targetpw/ALL rule, so tests are independent of the system configuration.
    """

    PASSWD = "test01Terah9ien7e"
    SUDO_GROUP = "wheel"
    # Override the system sudoers policy: disable targetpw, remove the
    # default ALL rule, and grant access only to the wheel group.
    # File is named 00-test to sort before any other sudoers.d entries.
    POLICY_NAME = "00-test-policy"
    POLICY = "%wheel ALL=(ALL:ALL) ALL\n"

    @pytest.fixture(autouse=True)
    def setup_policy(self, isolated_sudoers, sudoers_rules):
        sudoers_rules(self.POLICY_NAME, self.POLICY)

    def test_correct_password(self, test_users):
        """wheel group member with correct password gets root."""
        user = test_users("sudotest01a", self.PASSWD, [self.SUDO_GROUP])
        sudo_clear_timestamp()

        rc, stdout, stderr = sudo_as_user(user, self.PASSWD)
        assert rc == 0, f"sudo failed: {stderr}"
        assert stdout == "0", f"expected uid 0, got: {stdout}"

    def test_correct_password_repeated(self, test_users):
        """Two consecutive sudo calls in the same session both succeed."""
        user = test_users("sudotest01b", self.PASSWD, [self.SUDO_GROUP])
        sudo_clear_timestamp()

        # Run two sudo calls in a single su session so they share a tty
        # and the second can use the cached timestamp.
        inner_cmd = (
            f"echo '{self.PASSWD}' | sudo --stdin id -u && "
            f"echo '' | sudo --stdin id -u"
        )
        result = subprocess.run(
            ["su", "-", user, "-c", inner_cmd],
            stdout=PIPE, stderr=PIPE, universal_newlines=True, timeout=15,
        )
        assert result.returncode == 0, f"sudo failed: {result.stderr}"
        lines = result.stdout.strip().splitlines()
        assert lines == ["0", "0"], f"expected two uid 0 lines, got: {lines}"

    def test_wrong_password(self, test_users):
        """wheel group member with wrong password is rejected."""
        user = test_users("sudotest01c", self.PASSWD, [self.SUDO_GROUP])
        sudo_clear_timestamp()

        rc, stdout, stderr = sudo_as_user(user, "wrongpasswd")
        assert rc != 0, "sudo should have failed with wrong password"
        assert "Sorry, try again" in stderr or "incorrect password" in stderr

    def test_non_member_rejected(self, test_users):
        """User not in wheel group is rejected."""
        user = test_users("sudotest01d", self.PASSWD)
        sudo_clear_timestamp()

        rc, stdout, stderr = sudo_as_user(user, self.PASSWD)
        assert rc != 0, "sudo should have failed for non-member"
        assert "is not in the sudoers file" in stderr or "not allowed" in stderr


# -- Test 04: I/O redirection boundaries --
# Ported from sudo.pm lines 69-78
# Tests that shell redirections are NOT elevated by sudo.

class TestIORedirection:
    """Test I/O redirection boundary enforcement.

    Verifies that shell redirects (>, <) are processed by the user's
    shell and are not elevated by sudo. Also verifies that pipes through
    sudo work correctly for NOPASSWD commands.
    """

    PASSWD = "test04Ahqu4ohng"
    TEST_FILE = "/run/sudo-iotest"
    SUDOERS_NAME = "test-io-rules"
    # Grant NOPASSWD for dd, cat, and echo so we can test I/O without
    # password prompts. echo must be in the list because our isolated_sudoers
    # has no catch-all ALL rule -- without NOPASSWD, sudo echo would fail
    # before the redirect is even attempted.
    SUDOERS_CONTENT = (
        "testio ALL=(ALL) NOPASSWD: /usr/bin/dd, /usr/bin/cat, /usr/bin/echo\n"
    )

    @pytest.fixture(autouse=True)
    def setup_io(self, isolated_sudoers, test_users, sudoers_rules):
        self.user = test_users("testio", self.PASSWD)
        sudoers_rules(self.SUDOERS_NAME, self.SUDOERS_CONTENT)
        # Create a root-owned test file
        with open(self.TEST_FILE, "w") as f:
            f.write("1\n")
        os.chmod(self.TEST_FILE, 0o600)
        os.chown(self.TEST_FILE, 0, 0)
        yield
        if os.path.exists(self.TEST_FILE):
            os.unlink(self.TEST_FILE)

    def _run_as_user(self, shell_cmd):
        r = subprocess.run(
            ["su", "-", self.user, "-c", shell_cmd],
            stdout=PIPE, stderr=PIPE, universal_newlines=True, timeout=15,
        )
        if "No passwd entry" in r.stderr:
            raise RuntimeError(f"su failed for {self.user}: {r.stderr}")
        return r

    def test_output_redirect_not_elevated(self):
        """Shell output redirect to root-owned file fails even with sudo."""
        # sudo echo succeeds (NOPASSWD), but > is the user's shell redirect
        # which cannot open the root-owned file for writing.
        r = self._run_as_user(
            f"sudo echo overwrite > {self.TEST_FILE} 2>/dev/null"
        )
        assert r.returncode != 0, "redirect to root file should have failed"
        content = open(self.TEST_FILE).read().strip()
        assert content == "1", f"file was modified: {content}"

    def test_input_redirect_not_elevated(self):
        """Shell input redirect from root-owned file fails for non-root user."""
        r = self._run_as_user(
            f"sudo cat < {self.TEST_FILE} 2>/dev/null"
        )
        # The < redirect is processed by the user's shell which cannot
        # open the root-owned file. cat never runs.
        assert r.returncode != 0, "input redirect from root file should have failed"

    def test_pipe_write_through_sudo(self):
        """Pipe to sudo dd can write to root-owned file (dd runs as root)."""
        r = self._run_as_user(
            f"echo 3 | sudo dd of={self.TEST_FILE} 2>/dev/null"
        )
        assert r.returncode == 0, f"pipe through sudo dd failed: {r.stderr}"
        content = open(self.TEST_FILE).read().strip()
        assert content == "3", f"expected '3', got: {content}"

    def test_pipe_read_through_sudo(self):
        """sudo dd can read root-owned file and pipe to user's cat."""
        r = self._run_as_user(
            f"sudo dd if={self.TEST_FILE} 2>/dev/null | cat"
        )
        assert r.returncode == 0, f"pipe read failed: {r.stderr}"
        assert r.stdout.strip() == "1", f"expected '1', got: {r.stdout!r}"


# -- Test 05: interactive shell modes --
# Ported from sudo.pm lines 80-89
# Tests sudo -i (login shell) and sudo -s (non-login shell).

class TestShellModes:
    """Test sudo interactive shell modes.

    sudo -i spawns a login shell: user becomes root, cwd is /root.
    sudo -s spawns a non-login shell: user becomes root, cwd is unchanged.
    """

    PASSWD = "test05Aequ7ahnee"
    POLICY_NAME = "test-shell-policy"
    POLICY = "testshell ALL=(ALL:ALL) ALL\n"

    @pytest.fixture(autouse=True)
    def setup_shell(self, isolated_sudoers, test_users, sudoers_rules):
        self.user = test_users("testshell", self.PASSWD)
        sudoers_rules(self.POLICY_NAME, self.POLICY)

    def _sudo_shell_cmd(self, flag, cmd):
        """Run 'sudo <flag> <cmd>' as test user, return stdout."""
        inner = f"echo {self.PASSWD} | sudo -S {flag} {cmd} 2>/dev/null"
        r = subprocess.run(
            ["su", "-", self.user, "-c", inner],
            stdout=PIPE, stderr=PIPE, universal_newlines=True, timeout=15,
        )
        if "No passwd entry" in r.stderr:
            raise RuntimeError(f"su failed for {self.user}: {r.stderr}")
        # Filter out the password prompt line from output
        lines = [
            l for l in r.stdout.strip().splitlines()
            if "password for" not in l.lower()
        ]
        return r.returncode, "\n".join(lines).strip(), r.stderr

    def test_login_shell_whoami(self):
        """sudo -i runs as root."""
        rc, out, err = self._sudo_shell_cmd("-i", "whoami")
        assert rc == 0, f"sudo -i failed: {err}"
        assert out == "root", f"expected 'root', got: {out}"

    def test_login_shell_pwd(self):
        """sudo -i sets cwd to /root."""
        rc, out, err = self._sudo_shell_cmd("-i", "pwd")
        assert rc == 0, f"sudo -i pwd failed: {err}"
        assert out == "/root", f"expected '/root', got: {out}"

    def test_nonlogin_shell_whoami(self):
        """sudo -s runs as root."""
        rc, out, err = self._sudo_shell_cmd("-s", "whoami")
        assert rc == 0, f"sudo -s failed: {err}"
        assert out == "root", f"expected 'root', got: {out}"

    def test_nonlogin_shell_pwd(self):
        """sudo -s preserves cwd (user's home)."""
        rc, out, err = self._sudo_shell_cmd("-s", "pwd")
        assert rc == 0, f"sudo -s pwd failed: {err}"
        assert f"/home/{self.user}" in out, (
            f"expected '/home/{self.user}', got: {out}"
        )


# -- Test 06: environment variable isolation --
# Ported from sudo.pm lines 91-92
# Tests that env_reset prevents user env vars from leaking into sudo.

class TestEnvIsolation:
    """Test sudo environment variable isolation.

    With Defaults env_reset (the default), user environment variables
    should NOT be passed through to the sudo environment.
    """

    PASSWD = "test06Eeshoh3ei"
    POLICY_NAME = "test-env-policy"
    POLICY = "testenv ALL=(ALL:ALL) ALL\n"

    @pytest.fixture(autouse=True)
    def setup_env(self, isolated_sudoers, test_users, sudoers_rules):
        self.user = test_users("testenv", self.PASSWD)
        sudoers_rules(self.POLICY_NAME, self.POLICY)

    def test_env_not_passed(self):
        """User env vars are not passed through sudo (env_reset)."""
        inner = (
            f"export SUDOTEST_SECRET=xyzzy123; "
            f"echo {self.PASSWD} | sudo -S env 2>/dev/null"
        )
        r = subprocess.run(
            ["su", "-", self.user, "-c", inner],
            stdout=PIPE, stderr=PIPE, universal_newlines=True, timeout=15,
        )
        if "No passwd entry" in r.stderr:
            raise RuntimeError(f"su failed for {self.user}: {r.stderr}")
        assert "SUDOTEST_SECRET" not in r.stdout, (
            f"env var leaked through sudo: {r.stdout}"
        )


# -- Test 07: NOPASSWD/PASSWD mixed rules and group-based sudo --
# Ported from sudo.pm lines 46-58, 94-106
# Tests fine-grained command authorization and group-based rules.

class TestSudoersRules:
    """Test fine-grained sudoers command authorization.

    Verifies NOPASSWD vs PASSWD per-command rules, group-based access,
    and denial of unauthorized commands.
    """

    PASSWD = "test07Ohph4ia"
    USER_RULES = "test-user-rules"
    GROUP_RULES = "test-group-rules"

    @pytest.fixture(autouse=True)
    def setup_rules(self, isolated_sudoers, test_users, sudoers_rules):
        # Create test group and user
        ensure_group("sudotestgrp")
        self.user = test_users("testsudo07", self.PASSWD, ["sudotestgrp"])
        # User-specific rule: NOPASSWD for journalctl, PASSWD for visudo
        sudoers_rules(
            self.USER_RULES,
            "testsudo07 ALL=(ALL) NOPASSWD: /usr/bin/journalctl, /usr/bin/cat, "
            "PASSWD: /usr/sbin/visudo, /usr/bin/id\n"
        )
        # Group-based rule: group can run journalctl without password
        sudoers_rules(
            self.GROUP_RULES,
            "%sudotestgrp ALL=(ALL) NOPASSWD: /usr/bin/journalctl\n"
        )
        sudo_clear_timestamp()
        yield
        run(["groupdel", "sudotestgrp"], check=False)

    def _run_as_user(self, cmd):
        r = subprocess.run(
            ["su", "-", self.user, "-c", cmd],
            stdout=PIPE, stderr=PIPE, universal_newlines=True, timeout=15,
        )
        if "No passwd entry" in r.stderr:
            raise RuntimeError(f"su failed for {self.user}: {r.stderr}")
        return r

    def test_nopasswd_command(self):
        """NOPASSWD command runs without password (sudo -n)."""
        r = self._run_as_user("sudo -n cat /etc/hostname")
        assert r.returncode == 0, f"NOPASSWD cat failed: {r.stderr}"

    def test_passwd_command_rejected_noninteractive(self):
        """PASSWD command fails in non-interactive mode (sudo -n)."""
        r = self._run_as_user("sudo -n visudo --check 2>&1")
        assert r.returncode != 0, "PASSWD command should require password"
        assert "password is required" in r.stderr or "password is required" in r.stdout

    def test_unlisted_command_requires_password(self):
        """Command not in NOPASSWD list cannot run non-interactively."""
        r = self._run_as_user("sudo -n /usr/bin/whoami 2>&1")
        assert r.returncode != 0, "unlisted command should not run with -n"

    def test_group_nopasswd(self):
        """Group-based NOPASSWD rule works."""
        r = self._run_as_user("sudo -n journalctl -n1 --no-pager 2>&1")
        assert r.returncode == 0, f"group NOPASSWD failed: {r.stderr}{r.stdout}"


# -- Test 02: audit without DNS resolution --
# Ported from Debian 02-1003969-audit-no-resolve
# Tests that sudo works even when DNS is completely broken.

class TestAuditNoResolve:
    """Test sudo with broken DNS resolution."""

    def test_sudo_without_dns(self):
        """sudo id works even with empty resolv.conf and hosts."""
        resolv_backup = None
        hosts_backup = None
        tmpdir = tempfile.mkdtemp(prefix="sudo-test-02-")

        try:
            # Back up and empty resolv.conf
            if os.path.exists("/etc/resolv.conf"):
                resolv_backup = os.path.join(tmpdir, "resolv.conf")
                shutil.copy2("/etc/resolv.conf", resolv_backup)
                with open("/etc/resolv.conf", "w") as f:
                    pass  # empty

            # Back up and empty /etc/hosts
            if os.path.exists("/etc/hosts"):
                hosts_backup = os.path.join(tmpdir, "hosts")
                shutil.copy2("/etc/hosts", hosts_backup)
                with open("/etc/hosts", "w") as f:
                    pass  # empty

            # Run sudo as root (no password needed, avoids PAM issues)
            result = subprocess.run(
                ["sudo", "id", "-u"],
                stdout=PIPE, stderr=PIPE, universal_newlines=True, timeout=30,
            )

            # Filter out expected DNS warning from stderr
            unexpected = [
                line for line in result.stderr.splitlines()
                if "unable to resolve host" not in line
                and line.strip()
            ]
            assert result.returncode == 0, (
                f"sudo failed with rc={result.returncode}\n"
                f"stderr: {result.stderr}"
            )
            assert not unexpected, (
                f"unexpected stderr: {unexpected}\n"
                f"full stderr: {result.stderr}"
            )

        finally:
            # Restore resolv.conf and hosts
            if resolv_backup and os.path.exists(resolv_backup):
                shutil.copy2(resolv_backup, "/etc/resolv.conf")
            if hosts_backup and os.path.exists(hosts_backup):
                shutil.copy2(hosts_backup, "/etc/hosts")
            shutil.rmtree(tmpdir, ignore_errors=True)


# -- Test 03: sudoers.d file handling --
# Ported from Debian 03-1126085-sudoersd
# Tests that files in /etc/sudoers.d/ with special characters in their
# names are parsed correctly.

class TestSudoersD:
    """Test sudoers.d include file handling.

    Verifies that files in /etc/sudoers.d/ are parsed correctly,
    including filenames with hyphens and underscores.
    """

    # Each file grants a fake command path with a unique marker
    TEST_FILES = {
        "root": (
            "root ALL=(ALL:ALL) "
            "/usr/bin/----marker----/this-is-the-root-file\n"
        ),
        "10_test-special-chars": (
            "root ALL=(ALL:ALL) "
            "/usr/bin/----marker----/this-is-the-special-chars-file\n"
        ),
    }

    def test_sudoersd_files_parsed(self, sudoers_rules):
        """Rules from sudoers.d files appear in sudo -l output."""
        for name, content in self.TEST_FILES.items():
            sudoers_rules(name, content)

        result = run(["sudo", "-l"], check=False)
        marker_lines = [
            line.strip() for line in result.stdout.splitlines()
            if "----marker----" in line
        ]

        assert len(marker_lines) == len(self.TEST_FILES), (
            f"expected {len(self.TEST_FILES)} marker lines, "
            f"got {len(marker_lines)}:\n"
            f"  marker_lines: {marker_lines}\n"
            f"  full output: {result.stdout}"
        )

        # Verify each marker is present
        assert any("root-file" in l for l in marker_lines), (
            f"root-file marker missing: {marker_lines}"
        )
        assert any("special-chars-file" in l for l in marker_lines), (
            f"special-chars-file marker missing: {marker_lines}"
        )


# -- Test 08: shipped default sudoers validation --
# Validates the sudoers configuration as shipped by the sudo package.
# Does NOT replace or modify the config -- reads the real one.
# This catches the class of bugs where a package update changes the
# default behavior (e.g. targetpw removed, secure_path commented out,
# @includedir missing).

class TestShippedConfig:
    """Validate the shipped default sudoers configuration.

    These tests read the real sudoers file without modifying it.
    They verify that the configuration shipped by the sudo package
    meets SUSE's documented expectations.
    """

    def _find_sudoers(self):
        """Return the path to the active sudoers file."""
        for path in ["/etc/sudoers", "/usr/etc/sudoers"]:
            if os.path.exists(path):
                return path
        pytest.skip("no sudoers file found")

    def _read_sudoers_effective(self):
        """Return non-comment, non-empty lines from the active sudoers."""
        path = self._find_sudoers()
        lines = []
        with open(path) as f:
            for line in f:
                stripped = line.strip()
                if stripped and not stripped.startswith("#"):
                    # Remove inline comments
                    if "#" in stripped:
                        stripped = stripped[:stripped.index("#")].strip()
                    lines.append(stripped)
        return lines

    def test_sudoers_syntax_valid(self):
        """All sudoers files pass visudo --check."""
        r = run(["visudo", "--check", "--strict"], check=False)
        if r.returncode != 0:
            errors = [l for l in r.stderr.splitlines() if l.strip()]
            pytest.fail(
                "sudoers validation failed:\n" +
                "\n".join(f"  {e}" for e in errors),
                pytrace=False,
            )

    def test_sudoers_permissions(self):
        """The sudoers file has correct ownership and permissions."""
        path = self._find_sudoers()
        st = os.stat(path)
        mode = oct(st.st_mode & 0o7777)
        assert mode in ("0o440", "0o444"), (
            f"{path} has mode {mode}, expected 0440 or 0444"
        )
        assert st.st_uid == 0, f"{path} not owned by root (uid={st.st_uid})"

    def test_env_reset_enabled(self):
        """Defaults env_reset is set (prevents env variable leaks)."""
        lines = self._read_sudoers_effective()
        assert any("env_reset" in l and "!env_reset" not in l for l in lines), (
            "Defaults env_reset not found in sudoers"
        )

    def test_secure_path_set(self):
        """Defaults secure_path is set (prevents PATH injection)."""
        lines = self._read_sudoers_effective()
        assert any("secure_path" in l for l in lines), (
            "Defaults secure_path not found in sudoers"
        )

    def test_includedir_present(self):
        """@includedir directive exists for /etc/sudoers.d."""
        path = self._find_sudoers()
        with open(path) as f:
            content = f.read()
        has_etc = (
            "@includedir /etc/sudoers.d" in content
            or "#includedir /etc/sudoers.d" in content
        )
        has_usr_etc = (
            "@includedir /usr/etc/sudoers.d" in content
            or "#includedir /usr/etc/sudoers.d" in content
        )
        assert has_etc or has_usr_etc, (
            "no @includedir for sudoers.d found in sudoers"
        )

    def test_sudoersd_directory_exists(self):
        """/etc/sudoers.d directory exists with correct permissions."""
        assert os.path.isdir("/etc/sudoers.d"), (
            "/etc/sudoers.d directory does not exist"
        )
        st = os.stat("/etc/sudoers.d")
        mode = oct(st.st_mode & 0o7777)
        assert mode in ("0o750", "0o755", "0o700"), (
            f"/etc/sudoers.d has mode {mode}, expected 0750 or stricter"
        )

    def test_targetpw_consistency(self):
        """If targetpw is set, the ALL ALL rule must also be present.

        SUSE ships 'Defaults targetpw' + 'ALL ALL=(ALL) ALL' as a pair.
        Having targetpw without the ALL rule locks everyone out.
        Having the ALL rule without targetpw gives password-less-root-equiv
        to everyone (anyone can sudo with their own password).
        """
        lines = self._read_sudoers_effective()
        has_targetpw = any(
            "targetpw" in l and "!targetpw" not in l
            for l in lines
            if l.startswith("Defaults")
        )
        has_all_all = any(
            l.startswith("ALL") and "ALL=(ALL)" in l
            for l in lines
        )

        if has_targetpw:
            assert has_all_all, (
                "Defaults targetpw is set but ALL ALL=(ALL) ALL is missing. "
                "This locks out all non-root users."
            )
        if has_all_all and not has_targetpw:
            # Check if wheel policy overrides it
            wheel_override = any("!targetpw" in l for l in lines)
            if not wheel_override:
                # ALL ALL=(ALL) ALL without targetpw means everyone can
                # sudo with their OWN password. This is a known concern
                # but may be intentional (e.g. Agama installs).
                pass  # Don't fail, but this is notable


# -- main entry point --

if __name__ == "__main__":
    if os.geteuid() != 0:
        print("Error: tests require root privileges. Run with sudo.")
        raise SystemExit(1)
    pytest.main([__file__, "-v", "--tb=line"])
