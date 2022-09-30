# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test 'CAP_BPF' capability is available when 'unprivileged_bpf_disabled=1'
# Maintainer: QE Security <none@suse.de>
# Tags: poo#103932, tc#1769831, poo#108302

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $capability = 'cap_bpf';
    my $f_bpf_test = '/tmp/bpf_test';

    select_console 'root-console';
    # Set 'unprivileged_bpf_disabled' to 1
    validate_script_output('sysctl kernel.unprivileged_bpf_disabled=1', sub { m/kernel.unprivileged_bpf_disabled = 1/ });
    validate_script_output("cat /proc/sys/kernel/unprivileged_bpf_disabled", sub { m/1/ });

    # Download the C test code and compile
    assert_script_run('zypper -n in gcc libcap-progs', timeout => 300);
    assert_script_run('cd /tmp');
    assert_script_run('wget ' . autoinst_url . '/data/ebpf/bpf_test.c');
    assert_script_run("gcc -o $f_bpf_test bpf_test.c");
    # BPF system call should succeed with root permission
    validate_script_output("$f_bpf_test", sub { m/BPF: Success/ });

    # The `script_output` and `validate_script_output` function will create `script*.sh`
    # temporary files in `/tmp` directory to execute scripts, and it won't clean up automatically.
    # So we need to clean up the temp script file just created manually,
    # to avoid the permission denied issue in common user.
    script_run('rm /tmp/script*.sh');

    select_console 'user-console';
    # BPF system call should failed without root permission and cap_bpf capability
    validate_script_output($f_bpf_test, sub { m/BPF: Operation not permitted/ });

    # Grant cap_bpf capability to binary file just compiled
    select_console 'root-console';
    assert_script_run("getcap $f_bpf_test");
    assert_script_run("setcap $capability+eip $f_bpf_test");
    validate_script_output("getcap $f_bpf_test", sub { m/.*$capability.*/ });

    # BPF system call should succeed with cap_bpf capability in common user
    select_console 'user-console';
    validate_script_output($f_bpf_test, sub { m/BPF: Success/ });

    # Clean up the `/tmp` directory
    select_console 'root-console';
    script_run('rm /tmp/script*.sh');
    script_run("rm /tmp/bpf_test.c $f_bpf_test");
}

1;
