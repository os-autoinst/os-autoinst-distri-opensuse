# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: systemtap pass-4 runtime build and bsc#1226019 regression
#   Run the openQA-agnostic systemtap test from
#   data/console/openqa_agnostic/python/testSystemtap. It builds and loads
#   stap modules for the running kernel, including the bsc#1226019
#   vfs.read reproducer and the cpu_throttle example.
# Maintainer: Zoltan Balogh <zbalogh@suse.com>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';
use kdump_utils 'prepare_for_kdump';
use agnosticTestRunner;

sub run {
    select_serial_terminal;
    # vfs.read is a DWARF probe; only the debuginfo is needed here, not the
    # kdump packages that prepare_for_kdump installs by default.
    prepare_for_kdump(debuginfo_only => 1);
    my $packages = 'systemtap systemtap-docs kernel-default-devel gcc make';
    install_package($packages, trup_continue => 1, trup_reboot => 1);
    assert_script_run('test -f /lib/modules/$(uname -r)/build/Makefile',
        fail_message => 'kernel-default-devel does not match the running kernel; the image is probably older than the kernel update');
    # Verification hook: a Secure Boot SUT is already locked down; this flag
    # lets a normal SUT exercise the build-only path.
    if (get_var('SYSTEMTAP_FORCE_LOCKDOWN')) {
        assert_script_run('echo integrity > /sys/kernel/security/lockdown');
        record_info('lockdown', script_output('cat /sys/kernel/security/lockdown'));
    }

    my $test = agnosticTestRunner->new({
            language => 'python',
            name => 'testSystemtap',
            domain => 'console',
            run_timeout => 3600,
    });
    $test->setup()->run_test()->parse_results()->cleanup();
}

sub post_fail_hook {
    my ($self) = @_;
    # On a run_timeout pytest still owns the serial terminal.
    type_string("\cc");
    script_run('pkill -f "pytest.*test_systemtap"');
    script_run('pkill -x stap');
    script_run('pkill -x stapio');
    script_run('pkill -x cc1');
    upload_logs('/tmp/testSystemtap_output.log', failok => 1);
    $self->SUPER::post_fail_hook;
}

1;
