# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: stalld
# Summary: Install and validate the stalld package and service,
# and perform a basic upstream build and test check.
# Maintainer: QE Core <qe-core@suse.com>

use Mojo::Base 'consoletest';
use testapi;
use utils;
use serial_terminal 'select_serial_terminal';
use package_utils qw(install_package uninstall_package);

sub run {
    select_serial_terminal;

    my $pkg = "stalld";
    my $repo = "https://gitlab.com/rt-linux-tools/stalld.git";
    my $srcdir = "/tmp/stalld-src";

    # Install stalld package
    install_package("$pkg", trup_reboot => 1);
    assert_script_run("rpm -q $pkg");
    record_info("VERSION", script_output("stalld --version"));
    # Start service and verify service is active
    systemctl("enable --now stalld");
    systemctl("is-active stalld");
    validate_script_output("ps aux", sub { /stalld/ });

    # Configuration check
    if (script_run("test -f /etc/sysconfig/stalld") == 0) {
        assert_script_run("grep -v '^#' /etc/sysconfig/stalld || true");
        systemctl("restart stalld");
        systemctl("is-active stalld");
    }
    # Journal logs
    assert_script_run('journalctl -u stalld --no-pager | grep "Started Stall Monitor"');
    systemctl("stop stalld");
    # Running the upstream test suite
    # Install packages required for compiling stalld and running upstream tests
    install_package('git make clang bpftool libbpf-devel llvm', trup_reboot => 1);
    assert_script_run("rm -rf $srcdir");
    assert_script_run("git clone $repo $srcdir", timeout => 120);

    if (script_run("test -d $srcdir") == 0) {
        assert_script_run("cd $srcdir");
        assert_script_run("make clean", timeout => 300);
        assert_script_run("make", timeout => 300);
        assert_script_run("make clean -C tests");
        assert_script_run("make -C tests");
        # Find the system stalld binary path
        my $system_stalld = script_output("which stalld");
        record_info("SYSTEM_BIN", "Using system stalld from: $system_stalld");

        # Modify run_tests.sh to use the system binary
        assert_script_run("sed -i 's|STALLD_BIN=.*|STALLD_BIN=\"$system_stalld\"|' tests/run_tests.sh");

        validate_script_output("./tests/run_tests.sh --test test_cpu_selection", sub { m/Test PASSED/ }, timeout => 120);
    }
}

sub cleanup {
    my $pkg = "stalld";
    systemctl("stop stalld");
    uninstall_package("$pkg", trup_continue => 1, trup_reboot => 1);
    assert_script_run("rm -rf /tmp/stalld-src");
}

sub post_run_hook {
    cleanup();
}

sub post_fail_hook {
    cleanup();
}
1;
