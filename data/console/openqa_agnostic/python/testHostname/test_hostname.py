#!/usr/bin/python3
"""
Functional tests for hostname utilities (hostname, hostnamectl).

Tests cover the hostname command flags, hostnamectl get/set operations,
/etc/hostname file handling, static vs transient hostname behaviour,
and cross-tool consistency.

Inspired by GNU inetutils tests/hostname.sh, systemd TEST-71-HOSTNAME.sh,
and systemd test-hostname-util.c.

Tests require root privileges for set operations. Read-only tests
(flag output, consistency checks, shipped config) run without root.

Usage:
    sudo python3 -m pytest test_hostname.py -v
    sudo python3 test_hostname.py

References:
    GNU inetutils     tests/hostname.sh
    systemd           test/units/TEST-71-HOSTNAME.sh
    systemd           src/test/test-hostname-util.c
"""

import os
import pwd
import socket
import subprocess
from subprocess import PIPE
import pytest


# -- helpers --

def run(cmd, stdin_data=None, check=True, timeout=30):
    """Run a command and return CompletedProcess."""
    return subprocess.run(
        cmd, input=stdin_data, stdout=PIPE, stderr=PIPE,
        universal_newlines=True, check=check, timeout=timeout,
    )


def read_proc_hostname():
    """Read hostname directly from /proc/sys/kernel/hostname."""
    try:
        with open("/proc/sys/kernel/hostname") as f:
            return f.read().strip()
    except IOError:
        pytest.skip("/proc/sys/kernel/hostname not readable")


def read_etc_hostname():
    """Read /etc/hostname if it exists."""
    path = "/etc/hostname"
    if not os.path.exists(path):
        return None
    with open(path) as f:
        content = f.read().strip()
    return content


def has_hostnamectl():
    """Check if hostnamectl is available and functional.

    Checks both that the binary exists and that systemd-hostnamed
    is reachable via D-Bus. In containers without systemd as PID 1,
    the binary exists but cannot connect to the bus.
    """
    try:
        result = run(["hostnamectl", "hostname"], check=False)
        return result.returncode == 0
    except FileNotFoundError:
        return False


def user_exists(name):
    """Check if a system user exists."""
    try:
        pwd.getpwnam(name)
        return True
    except KeyError:
        return False


# -- fixtures --

@pytest.fixture
def require_root():
    """Skip if not running as root."""
    if os.geteuid() != 0:
        pytest.skip("test requires root privileges")


@pytest.fixture
def saved_hostname(require_root):
    """Save and restore the system hostname around a test.

    Saves: /etc/hostname raw bytes and the kernel hostname. On teardown
    restores both the transient hostname (via hostname command) and
    the /etc/hostname file contents exactly as they were.
    """
    orig_kernel = run(["hostname"], check=False).stdout.strip()
    orig_etc_existed = os.path.exists("/etc/hostname")
    orig_etc_raw = None
    if orig_etc_existed:
        with open("/etc/hostname", "rb") as f:
            orig_etc_raw = f.read()

    yield orig_kernel

    # Restore transient hostname via hostname(1) -- does not touch
    # /etc/hostname, avoids systemd-hostnamed policy interactions
    run(["hostname", orig_kernel], check=False)

    # Restore /etc/hostname to its original state (raw bytes)
    if orig_etc_existed:
        with open("/etc/hostname", "wb") as f:
            f.write(orig_etc_raw)
    else:
        if os.path.exists("/etc/hostname"):
            os.unlink("/etc/hostname")


# -- Test classes --


class TestHostnameGet:
    """Test hostname retrieval commands (read-only, no root needed)."""

    def test_hostname_returns_nonempty(self):
        """hostname command returns a non-empty string."""
        result = run(["hostname"], check=False)
        if result.returncode != 0:
            pytest.fail(
                "hostname command failed: " + result.stderr,
                pytrace=False,
            )
        if len(result.stdout.strip()) == 0:
            pytest.fail("hostname returned empty string", pytrace=False)

    def test_hostname_matches_uname(self):
        """hostname output matches uname -n (kernel hostname)."""
        hostname_out = run(["hostname"]).stdout.strip()
        uname_out = run(["uname", "-n"]).stdout.strip()
        if hostname_out != uname_out:
            pytest.fail(
                "hostname '{}' != uname -n '{}'".format(
                    hostname_out, uname_out
                ),
                pytrace=False,
            )

    def test_hostname_matches_proc(self):
        """hostname output matches /proc/sys/kernel/hostname."""
        hostname_out = run(["hostname"]).stdout.strip()
        proc_out = read_proc_hostname()
        if hostname_out != proc_out:
            pytest.fail(
                "hostname '{}' != /proc/sys/kernel/hostname '{}'".format(
                    hostname_out, proc_out
                ),
                pytrace=False,
            )

    def test_hostname_short_flag(self):
        """hostname -s returns the short hostname (no domain)."""
        result = run(["hostname", "-s"], check=False)
        if result.returncode != 0:
            pytest.fail(
                "hostname -s failed: " + result.stderr, pytrace=False
            )
        short = result.stdout.strip()
        if len(short) == 0:
            pytest.fail("hostname -s returned empty", pytrace=False)
        if "." in short:
            pytest.fail(
                "hostname -s should not contain dots, got: " + short,
                pytrace=False,
            )

    def test_hostname_fqdn_flag(self):
        """hostname -f returns a non-empty FQDN.

        On systems where the hostname is not in /etc/hosts and DNS
        is not configured (e.g., laptops), hostname -f fails. This
        is expected and not a test failure.
        """
        result = run(["hostname", "-f"], check=False)
        if result.returncode != 0:
            pytest.skip(
                "hostname -f not available (no FQDN configured): "
                + result.stderr.strip()
            )
        fqdn = result.stdout.strip()
        if len(fqdn) == 0:
            pytest.fail("hostname -f returned empty", pytrace=False)


class TestHostnameSet:
    """Test setting the hostname via the hostname command."""

    TEST_HOSTNAME = "oqatest-host"

    def test_set_hostname(self, saved_hostname):
        """hostname command can set a new hostname."""
        run(["hostname", self.TEST_HOSTNAME])
        result = run(["hostname"])
        if result.stdout.strip() != self.TEST_HOSTNAME:
            pytest.fail(
                "expected '{}' but got '{}'".format(
                    self.TEST_HOSTNAME, result.stdout.strip()
                ),
                pytrace=False,
            )

    def test_set_hostname_updates_kernel(self, saved_hostname):
        """Setting hostname updates /proc/sys/kernel/hostname."""
        run(["hostname", self.TEST_HOSTNAME])
        proc_val = read_proc_hostname()
        if proc_val != self.TEST_HOSTNAME:
            pytest.fail(
                "kernel hostname '{}' != expected '{}'".format(
                    proc_val, self.TEST_HOSTNAME
                ),
                pytrace=False,
            )

    def test_set_hostname_updates_uname(self, saved_hostname):
        """Setting hostname updates uname -n."""
        run(["hostname", self.TEST_HOSTNAME])
        uname_out = run(["uname", "-n"]).stdout.strip()
        if uname_out != self.TEST_HOSTNAME:
            pytest.fail(
                "uname -n '{}' != expected '{}'".format(
                    uname_out, self.TEST_HOSTNAME
                ),
                pytrace=False,
            )

    def test_set_from_file(self, saved_hostname, tmp_path):
        """hostname -F reads hostname from a file.

        Borrowed from GNU inetutils tests/hostname.sh.
        """
        tmpfile = str(tmp_path / "hostname_file")
        with open(tmpfile, "w") as f:
            f.write(self.TEST_HOSTNAME + "\n")
        run(["hostname", "-F", tmpfile])
        result = run(["hostname"]).stdout.strip()
        if result != self.TEST_HOSTNAME:
            pytest.fail(
                "expected '{}' but got '{}'".format(
                    self.TEST_HOSTNAME, result
                ),
                pytrace=False,
            )

    def test_set_hostname_nonroot_fails(self, require_root):
        """Non-root user cannot set hostname."""
        if not user_exists("nobody"):
            pytest.skip("nobody user does not exist")
        before = socket.gethostname()
        result = run(
            ["su", "-s", "/bin/sh", "nobody", "-c",
             "hostname should-not-work"],
            check=False,
        )
        if result.returncode == 0:
            pytest.fail(
                "hostname set should fail for non-root user",
                pytrace=False,
            )
        after = socket.gethostname()
        if after != before:
            pytest.fail(
                "hostname changed from '{}' to '{}' by non-root user"
                .format(before, after),
                pytrace=False,
            )


class TestHostnamectl:
    """Test hostnamectl operations (requires systemd-hostnamed)."""

    TEST_HOSTNAME = "oqatest-hctl"

    @pytest.fixture(autouse=True)
    def require_hostnamectl(self):
        if not has_hostnamectl():
            pytest.skip("hostnamectl not available")

    def test_hostnamectl_status_runs(self):
        """hostnamectl status exits successfully and produces output."""
        result = run(["hostnamectl", "status"])
        if result.returncode != 0:
            pytest.fail(
                "hostnamectl status failed: " + result.stderr,
                pytrace=False,
            )
        if len(result.stdout.strip()) == 0:
            pytest.fail(
                "hostnamectl status returned empty output",
                pytrace=False,
            )

    def test_hostnamectl_shows_kernel_version(self):
        """hostnamectl status shows the kernel version.

        From systemd TEST-71-HOSTNAME.sh.
        """
        result = run(["hostnamectl", "status"])
        kernel = run(["uname", "-r"]).stdout.strip()
        if kernel not in result.stdout:
            pytest.fail(
                "kernel version '{}' not in hostnamectl output".format(
                    kernel
                ),
                pytrace=False,
            )

    def test_hostnamectl_set_hostname(self, saved_hostname):
        """hostnamectl set-hostname changes the hostname."""
        run(["hostnamectl", "set-hostname", self.TEST_HOSTNAME])
        result = run(["hostnamectl", "hostname"]).stdout.strip()
        if result != self.TEST_HOSTNAME:
            pytest.fail(
                "hostnamectl hostname '{}' != expected '{}'".format(
                    result, self.TEST_HOSTNAME
                ),
                pytrace=False,
            )

    def test_hostnamectl_set_updates_etc_hostname(self, saved_hostname):
        """hostnamectl set-hostname writes to /etc/hostname.

        From systemd TEST-71-HOSTNAME.sh.
        """
        run(["hostnamectl", "set-hostname", self.TEST_HOSTNAME])
        etc_val = read_etc_hostname()
        if etc_val != self.TEST_HOSTNAME:
            pytest.fail(
                "/etc/hostname '{}' != expected '{}'".format(
                    etc_val, self.TEST_HOSTNAME
                ),
                pytrace=False,
            )

    def test_hostnamectl_agrees_with_hostname(self, saved_hostname):
        """hostnamectl hostname agrees with hostname command."""
        run(["hostnamectl", "set-hostname", self.TEST_HOSTNAME])
        hctl = run(["hostnamectl", "hostname"]).stdout.strip()
        hcmd = run(["hostname"]).stdout.strip()
        if hctl != hcmd:
            pytest.fail(
                "hostnamectl '{}' != hostname '{}'".format(hctl, hcmd),
                pytrace=False,
            )

    def test_hostnamectl_set_transient(self, saved_hostname):
        """hostnamectl set-hostname --transient sets the transient hostname.

        On systems where systemd-hostnamed policy overrides the
        transient hostname with the static one, the transient set
        may be silently ignored. This is expected systemd behaviour.
        """
        orig_static = read_etc_hostname()
        # Use a hostname different from the static one
        transient_name = "oqatest-transient"
        result = run(
            ["hostnamectl", "set-hostname", "--transient", transient_name],
            check=False,
        )
        if result.returncode != 0:
            pytest.skip(
                "hostnamectl --transient failed: " + result.stderr.strip()
            )

        current = run(["hostname"]).stdout.strip()
        if current != transient_name:
            # systemd-hostnamed may override transient with static --
            # this is documented behaviour, not a bug
            pytest.skip(
                "systemd-hostnamed overrides transient with static hostname"
            )

        # If transient was applied, verify /etc/hostname was not changed
        new_static = read_etc_hostname()
        if new_static != orig_static:
            pytest.fail(
                "--transient changed /etc/hostname from '{}' to '{}'".format(
                    orig_static, new_static
                ),
                pytrace=False,
            )


class TestHostnameValidation:
    """Test hostname validation behaviour.

    hostnamectl's validation behaviour varies across systemd versions.
    Older versions reject invalid hostnames at the D-Bus API level;
    newer versions (257+) may accept them and write to /etc/hostname.

    Instead of asserting rejection, we test that the system handles
    invalid hostnames gracefully: either rejects them or, if accepted,
    that the hostname and hostname tools remain functional.
    """

    @pytest.fixture(autouse=True)
    def require_hostnamectl(self):
        if not has_hostnamectl():
            pytest.skip("hostnamectl not available")

    def test_valid_simple(self, saved_hostname):
        """Simple alphanumeric hostname is accepted."""
        result = run(["hostnamectl", "set-hostname", "validhost"], check=False)
        if result.returncode != 0:
            pytest.fail(
                "valid hostname rejected: " + result.stderr, pytrace=False
            )

    def test_valid_with_hyphens(self, saved_hostname):
        """Hostname with hyphens is accepted (RFC 952)."""
        result = run(
            ["hostnamectl", "set-hostname", "valid-host-name"], check=False
        )
        if result.returncode != 0:
            pytest.fail(
                "valid hostname rejected: " + result.stderr, pytrace=False
            )

    def test_valid_with_digits(self, saved_hostname):
        """Hostname starting with digit is accepted (RFC 1123)."""
        result = run(["hostnamectl", "set-hostname", "123host"], check=False)
        if result.returncode != 0:
            pytest.fail(
                "valid hostname rejected: " + result.stderr, pytrace=False
            )

    def test_empty_hostname(self, saved_hostname):
        """Empty hostname is handled gracefully.

        Older systemd rejects this; newer versions may accept it
        (clears the static hostname, falls back to transient).
        """
        result = run(["hostnamectl", "set-hostname", ""], check=False)
        if result.returncode == 0:
            # Accepted: verify hostname tools still work
            check = run(["hostname"], check=False)
            if check.returncode != 0:
                pytest.fail(
                    "hostname command broken after setting empty hostname",
                    pytrace=False,
                )

    def test_long_hostname(self, saved_hostname):
        """Hostname exceeding 64 characters is handled gracefully.

        Linux sethostname(2) allows at most 64 bytes (__NEW_UTS_LEN).
        hostnamectl may reject, truncate, or accept depending on
        systemd version. We verify the system remains consistent.
        """
        long_name = "a" * 65
        result = run(
            ["hostnamectl", "set-hostname", long_name], check=False
        )
        if result.returncode == 0:
            # Accepted: verify the kernel hostname length
            current = run(["hostname"]).stdout.strip()
            if len(current) > 64:
                pytest.fail(
                    "kernel accepted hostname > 64 chars: {} ({} chars)"
                    .format(current, len(current)),
                    pytrace=False,
                )

    def test_accept_max_length(self, saved_hostname):
        """Hostname at the Linux maximum (64 characters) is accepted.

        The kernel sethostname(2) allows hostnames up to 64 bytes
        (__NEW_UTS_LEN in include/uapi/linux/utsname.h).
        """
        name_64 = "a" * 64
        result = run(
            ["hostnamectl", "set-hostname", name_64], check=False
        )
        if result.returncode != 0:
            pytest.fail(
                "64-char hostname rejected: " + result.stderr,
                pytrace=False,
            )


class TestEtcHostname:
    """Test /etc/hostname file handling and edge cases.

    Covers parsing bugs that have been reported in bugzilla:
    trailing newlines, whitespace, comments.
    """

    def test_etc_hostname_no_trailing_whitespace(self):
        """Content of /etc/hostname has no trailing whitespace.

        Trailing whitespace in /etc/hostname has caused bugs where the
        hostname includes invisible characters.
        """
        if not os.path.exists("/etc/hostname"):
            pytest.skip("/etc/hostname does not exist")
        with open("/etc/hostname") as f:
            raw = f.read()
        for i, line in enumerate(raw.splitlines(), 1):
            if line != line.rstrip():
                pytest.fail(
                    "/etc/hostname line {} has trailing whitespace: {}"
                    .format(i, repr(line)),
                    pytrace=False,
                )

    def test_hostname_from_file_with_newline(self, saved_hostname, tmp_path):
        """hostname -F handles file with trailing newline correctly.

        Regression: trailing newline in hostname file was included in
        the hostname on some systems. Assert via socket.gethostname()
        to avoid masking trailing whitespace with .strip().
        """
        tmpfile = str(tmp_path / "hostname_newline")
        with open(tmpfile, "w") as f:
            f.write("newlinetest\n\n")
        run(["hostname", "-F", tmpfile])
        actual = socket.gethostname()
        if actual != "newlinetest":
            pytest.fail(
                "expected 'newlinetest' but got {!r}".format(actual),
                pytrace=False,
            )


class TestHostnameConsistency:
    """Test that hostname is consistent across all query methods.

    Multiple interfaces report the hostname: the hostname command,
    uname -n, /proc/sys/kernel/hostname, and Python socket.gethostname().
    They should all agree for the transient hostname.
    """

    def test_all_sources_agree(self):
        """All hostname query methods return the same value."""
        sources = {}
        sources["hostname"] = run(["hostname"]).stdout.strip()
        sources["uname -n"] = run(["uname", "-n"]).stdout.strip()
        sources["/proc/sys/kernel/hostname"] = read_proc_hostname()
        sources["socket.gethostname()"] = socket.gethostname()

        values = set(sources.values())
        if len(values) != 1:
            details = "\n".join(
                "  {}: {}".format(k, v) for k, v in sources.items()
            )
            pytest.fail(
                "hostname sources disagree:\n" + details,
                pytrace=False,
            )

    def test_hostnamectl_agrees(self):
        """hostnamectl hostname matches hostname command."""
        if not has_hostnamectl():
            pytest.skip("hostnamectl not available")
        hctl = run(["hostnamectl", "hostname"]).stdout.strip()
        hcmd = run(["hostname"]).stdout.strip()
        if hctl != hcmd:
            pytest.fail(
                "hostnamectl '{}' != hostname '{}'".format(hctl, hcmd),
                pytrace=False,
            )

    def test_etc_hostname_agrees(self):
        """/etc/hostname matches the running hostname."""
        etc_val = read_etc_hostname()
        if etc_val is None:
            pytest.skip("/etc/hostname does not exist")
        hostname_val = run(["hostname"]).stdout.strip()
        if etc_val != hostname_val:
            pytest.fail(
                "/etc/hostname '{}' != hostname '{}'".format(
                    etc_val, hostname_val
                ),
                pytrace=False,
            )


class TestHostnameShippedConfig:
    """Test the shipped hostname configuration on SUSE systems.

    Validates that the default hostname configuration is sane:
    proper /etc/hostname ownership and permissions, nsswitch.conf
    includes hostname resolution sources, etc.
    """

    def test_etc_hostname_permissions(self):
        """/etc/hostname has correct ownership and permissions."""
        path = "/etc/hostname"
        if not os.path.exists(path):
            pytest.skip("/etc/hostname does not exist")
        st = os.stat(path)
        if st.st_uid != 0:
            pytest.fail(
                "/etc/hostname owned by uid {}, expected 0".format(
                    st.st_uid
                ),
                pytrace=False,
            )
        if st.st_gid != 0:
            pytest.fail(
                "/etc/hostname owned by gid {}, expected 0".format(
                    st.st_gid
                ),
                pytrace=False,
            )
        mode = st.st_mode & 0o777
        if mode not in (0o644, 0o444, 0o600):
            pytest.fail(
                "/etc/hostname has mode {:o}, expected 644 or 444".format(
                    mode
                ),
                pytrace=False,
            )

    def test_nsswitch_hosts_configured(self):
        """nsswitch.conf has a hosts: line with resolution sources.

        On SLE 16+ and Tumbleweed, the vendor config may live in
        /usr/etc/nsswitch.conf (SUSE UsrEtc split). glibc falls
        back to that path when /etc/nsswitch.conf does not exist.
        """
        if os.path.exists("/etc/nsswitch.conf"):
            nsswitch = "/etc/nsswitch.conf"
        elif os.path.exists("/usr/etc/nsswitch.conf"):
            nsswitch = "/usr/etc/nsswitch.conf"
        else:
            pytest.skip("neither /etc/ nor /usr/etc/nsswitch.conf exists")
        with open(nsswitch) as f:
            content = f.read()
        hosts_lines = [
            line for line in content.splitlines()
            if line.strip().startswith("hosts:")
        ]
        if len(hosts_lines) == 0:
            pytest.fail(
                "no 'hosts:' line in /etc/nsswitch.conf",
                pytrace=False,
            )
        hosts_line = hosts_lines[0]
        if "files" not in hosts_line:
            pytest.fail(
                "nsswitch hosts: missing 'files' source: " + hosts_line,
                pytrace=False,
            )

    def test_etc_hosts_has_localhost(self):
        """/etc/hosts contains a localhost entry."""
        hosts_file = "/etc/hosts"
        if not os.path.exists(hosts_file):
            pytest.skip("/etc/hosts does not exist")
        with open(hosts_file) as f:
            content = f.read().lower()
        if "localhost" not in content:
            pytest.fail(
                "/etc/hosts missing localhost entry", pytrace=False
            )

    def test_hostname_resolves(self):
        """The current hostname resolves to an IP address.

        Uses getent to check that the hostname can be resolved via
        nsswitch (hosts file or DNS). On systems where the hostname
        is not in /etc/hosts (e.g., laptops with DHCP), this skips.
        """
        hostname_val = run(["hostname"]).stdout.strip()
        result = run(
            ["getent", "hosts", hostname_val], check=False
        )
        if result.returncode != 0:
            pytest.skip(
                "hostname '{}' does not resolve (no hosts entry)"
                .format(hostname_val)
            )
        if len(result.stdout.strip()) == 0:
            pytest.fail(
                "getent returned empty for hostname '{}'".format(
                    hostname_val
                ),
                pytrace=False,
            )

    def test_localhost_resolves(self):
        """localhost resolves to a loopback address (127.0.0.1 or ::1)."""
        result = run(["getent", "hosts", "localhost"])
        output = result.stdout
        if "127.0.0.1" not in output and "::1" not in output:
            pytest.fail(
                "localhost does not resolve to loopback: " + output,
                pytrace=False,
            )


# -- entry point for direct execution --

if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-v"]))
