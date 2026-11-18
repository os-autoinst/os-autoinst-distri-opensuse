# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Test the SELinux command line tools: ls/id/ps -Z, selinuxexeccon, chcon,
# chcat and restorecon. The code is compatible with Python 3.6 and pytest 5.
# Tags: poo#206877

import os
import re
import shutil
import subprocess
import tempfile

import pytest

FCONTEXT_TYPE1 = "etc_t"
FCONTEXT_TYPE2 = "bin_t"
TEST_USER = "root"
SYSTEMLOW = "s0"
SYSTEMHIGH = "s0:c0.c1023"
TEST_CATEGORY = "c0.c1023"
# Matches a "user_u:role_r:type_t:level" security context
CONTEXT_RE = r"\S+_u:\S+_r:\S+_t:\S+"


def run(cmd):
    """
    Run a command and collect its output.

    :param cmd list: command and its arguments
    :return subprocess.CompletedProcess: result, stderr is merged into stdout
    """
    print("+ " + " ".join(cmd))
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            universal_newlines=True)
    print(result.stdout, end="")
    return result


def assert_run(cmd):
    """
    Run a command and make sure that it exits with 0.

    :param cmd list: command and its arguments
    :return str: output of the command
    """
    result = run(cmd)
    assert result.returncode == 0, "'{}' failed with exit code {}:\n{}".format(
        " ".join(cmd), result.returncode, result.stdout)
    return result.stdout


def raw_context(path):
    """
    Read the raw SELinux context of a file directly from its extended attribute.
    This value is not changed by an MCS translation daemon (mcstransd).

    :param path str: path to a file or a directory
    :return str: security context, for example "system_u:object_r:etc_t:s0"
    """
    return os.getxattr(path, "security.selinux").decode().rstrip("\0")


def context_type(path):
    """
    Get the SELinux type of a file.

    :param path str: path to a file or a directory
    :return str: SELinux type, for example "etc_t"
    """
    return raw_context(path).split(":")[2]


def context_level(path):
    """
    Get the SELinux MLS/MCS level of a file.

    :param path str: path to a file or a directory
    :return str: level, for example "s0" or "s0:c0.c1023"
    """
    return raw_context(path).split(":", 3)[3]


def user_range(user):
    """
    Get the MLS/MCS range that "chcat -L -l" reports for a Linux user.

    :param user str: Linux user name
    :return str: output line of chcat for the user, for example "root: s0-s0:c0.c1023"
    """
    out = assert_run(["chcat", "-L", "-l", user])
    lines = [line.strip() for line in out.splitlines() if line.startswith(user + ":")]
    assert lines, "chcat did not report a range for user {}:\n{}".format(user, out)
    return lines[0]


@pytest.fixture(scope="module", autouse=True)
def selinux_enabled():
    """
    Skip all tests in this file when SELinux is disabled.
    """
    if run(["selinuxenabled"]).returncode != 0:
        pytest.skip("SELinux is disabled")


@pytest.fixture
def test_tree():
    """
    Create a test directory with a test file in it. Remove them after the test.

    :return tuple: (path of the test directory, path of the test file)
    """
    test_dir = tempfile.mkdtemp(prefix="selinux_tools_", dir="/tmp")
    test_file = os.path.join(test_dir, "testfile")
    open(test_file, "w").close()
    try:
        yield test_dir, test_file
    finally:
        shutil.rmtree(test_dir, ignore_errors=True)


@pytest.fixture
def fcontext_rules():
    """
    Give a function that adds local file context rules with "semanage fcontext -a".
    Remove only the rules that the test added, other local rules stay.

    :return function: add(fcontext_type, path)
    """
    added = []

    def add(fcontext_type, path):
        assert_run(["semanage", "fcontext", "-a", "-t", fcontext_type, path])
        added.append(path)

    try:
        yield add
    finally:
        for path in reversed(added):
            run(["semanage", "fcontext", "-d", path])


@pytest.fixture
def restore_user_mapping():
    """
    Save the SELinux login mapping of TEST_USER and put it back after the test,
    because "chcat -l" changes the mapping of the user for the whole system.
    """
    out = assert_run(["semanage", "login", "-l", "-C"])
    saved = None
    for line in out.splitlines():
        fields = line.split()
        if len(fields) >= 3 and fields[0] == TEST_USER:
            saved = fields
    try:
        yield
    finally:
        if saved is None:
            # The user had no local mapping before the test
            run(["semanage", "login", "-d", TEST_USER])
        else:
            run(["semanage", "login", "-m", "-s", saved[1], "-r", saved[2], TEST_USER])
        print("Mapping of {} after cleanup: {}".format(TEST_USER, user_range(TEST_USER)))


def test_secontext_ls_z_file(test_tree):
    """
    "ls -Z" prints the security context of a file.
    """
    _, test_file = test_tree
    out = assert_run(["ls", "-Z", test_file])
    assert re.search(CONTEXT_RE + r"\s+.*" + re.escape(test_file), out)


def test_secontext_ls_z_dir():
    """
    "ls -Zd" prints the security context of a directory.
    """
    out = assert_run(["ls", "-Zd", "/root"])
    assert re.search(CONTEXT_RE + r"\s+/root", out)


def test_secontext_id_z():
    """
    "id -Z" prints the security context of the current user.
    """
    out = assert_run(["id", "-Z"])
    assert re.search(r"^" + CONTEXT_RE + r"$", out.strip())


def test_secontext_ps_z():
    """
    "ps -Z" prints the security context of a process. The context of this
    process must be the same as the one that the kernel reports in /proc.
    """
    pid = os.getpid()
    with open("/proc/{}/attr/current".format(pid)) as f:
        expected = f.read().strip("\0\n ")
    out = assert_run(["ps", "-Z", "-p", str(pid)])
    assert re.search(CONTEXT_RE + r"\s+" + str(pid) + r"\s", out)
    assert expected in out, "context {} of PID {} not found in:\n{}".format(expected, pid, out)


def test_selinuxexeccon():
    """
    "selinuxexeccon" reports the process context for a command started from
    the current context.
    """
    out = assert_run(["selinuxexeccon", "/usr/bin/passwd"])
    assert re.search(r"\S+_u:\S+_r:\S+_t:s\S*:c\S*", out)


def test_chcon(test_tree):
    """
    "chcon -t" changes the SELinux type of a file.
    """
    _, test_file = test_tree
    for fcontext_type in (FCONTEXT_TYPE1, FCONTEXT_TYPE2):
        assert_run(["chcon", "-t", fcontext_type, test_file])
        assert context_type(test_file) == fcontext_type


def test_restorecon(test_tree, fcontext_rules):
    """
    "restorecon" labels files as the local file context rules tell.
    """
    test_dir, test_file = test_tree
    fcontext_rules(FCONTEXT_TYPE1, test_dir)
    fcontext_rules(FCONTEXT_TYPE2, test_file)
    local_rules = assert_run(["semanage", "fcontext", "-l", "-C"])
    assert re.search(re.escape(test_dir) + r"\s.*" + FCONTEXT_TYPE1, local_rules)
    assert re.search(re.escape(test_file) + r"\s.*" + FCONTEXT_TYPE2, local_rules)

    # -R -v: label the tree recursively and show the changes
    out = assert_run(["restorecon", "-R", "-v", test_dir])
    assert "Relabeled" in out
    assert context_type(test_dir) == FCONTEXT_TYPE1
    assert context_type(test_file) == FCONTEXT_TYPE2

    # -R -p: give the file a wrong label and restore it, show the progress
    assert_run(["chcon", "-t", FCONTEXT_TYPE1, test_file])
    assert context_type(test_file) == FCONTEXT_TYPE1
    assert_run(["restorecon", "-R", "-p", test_dir])
    assert context_type(test_file) == FCONTEXT_TYPE2


def test_chcat_list():
    """
    "chcat -L" lists the available levels and categories.
    """
    out = assert_run(["chcat", "-L"])
    assert re.search(
        r"s0\s.*SystemLow.*"
        r"s0-s0:c0\.c1023\s.*SystemLow-SystemHigh.*"
        r"s0:c0\.c1023\s.*SystemHigh", out, re.DOTALL)


@pytest.mark.parametrize("target", ["dir", "file"])
def test_chcat_on_files(test_tree, target):
    """
    "chcat +CATEGORY" adds and "chcat -CATEGORY" / "chcat -d" removes
    categories of a directory or a file.

    :param target str: "dir" to test the directory, "file" to test the file
    """
    test_dir, test_file = test_tree
    path = test_dir if target == "dir" else test_file
    assert context_level(path) == SYSTEMLOW
    assert_run(["chcat", "+" + TEST_CATEGORY, path])
    assert context_level(path) == SYSTEMHIGH
    if target == "dir":
        assert_run(["chcat", "--", "-" + TEST_CATEGORY, path])
    else:
        assert_run(["chcat", "-d", path])
    assert context_level(path) == SYSTEMLOW


def test_chcat_on_user(restore_user_mapping):
    """
    "chcat -l" changes the categories of a Linux user instead of a file.
    """
    assert user_range(TEST_USER).endswith(SYSTEMHIGH)
    assert_run(["chcat", "-l", "-d", TEST_USER])
    assert user_range(TEST_USER).endswith(SYSTEMLOW)
    assert_run(["chcat", "-l", "+" + TEST_CATEGORY, TEST_USER])
    assert user_range(TEST_USER).endswith(SYSTEMHIGH)
