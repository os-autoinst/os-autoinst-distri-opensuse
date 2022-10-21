# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: RT tests
#    test kmp modules & boot RT kernel script for further automated and regression RT tests
#    list of KMP rpms: cluster-md-kmp-rt, gfs2-kmp-rt, dlm-kmp-rt, crash-kmp-rt, oracleasm-kmp-rt
#    lttng-modules-kmp-rt, ocfs2-kmp-rt
# Maintainer: QE Kernel <kernel-qa@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils qw(zypper_call clear_console);
use version_utils qw(is_sle);
use rt_utils qw(select_kernel);
use File::Basename qw(fileparse);
use power_action_utils qw(power_action);
use Utils::Systemd qw(systemctl);

sub run_lttng_demo_trace {
    my $trace = {
        label => 'TEST_TRACE',
        output => '/tmp/sched_trace_example',
        component => 'sched_switch',
        channel => 'test-channel'
    };

    # Trace demo
    assert_script_run 'lttng create ' . $trace->{label} . ' -o ' . $trace->{output};
    assert_script_run 'lttng enable-channel --kernel ' . $trace->{channel};
    assert_script_run 'lttng enable-event --kernel -a ' . $trace->{component} . ' -c ' . $trace->{channel};
    assert_script_run 'lttng start';
    assert_script_run 'sleep 5';
    assert_script_run 'lttng list ' . $trace->{label};
    assert_script_run 'lttng stop';
    assert_script_run 'lttng destroy -a';
    if ((script_run "test -e $trace->{output}") == 0) {
        assert_script_run "ls -la $trace->{output}" . '/kernel';
        if ((script_run('test -f ' . $trace->{output} . '/kernel/' . $trace->{channel} . '_0')) == 0) {
            assert_script_run "file $trace->{output}" . '/kernel/' . $trace->{channel} . '_0';
        } else {
            die 'Trace file ' . $trace->{output} . '/kernel/' . $trace->{channel} . "_0 is missing!\n";
        }
    } else {
        die "Trace files directory \"$trace->{output}\" does not exist!\n";
    }
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Stop packagekit
    systemctl 'mask packagekit.service';
    systemctl 'stop packagekit.service';

    # allow to load unsupported modules
    script_run 'sed -i s\'/^allow_unsupported_modules 0/allow_unsupported_modules 1/\' /etc/modprobe.d/10-unsupported-modules.conf';

    # install kmp packages
    zypper_call 'ref';
    zypper_call 'in lttng-tools *-kmp-rt', 500;

    # Reboot in order to select RT kernel
    if (script_run q|grep -E 'BOOT_IMAGE=/boot/vmlinuz-.*-[[:digit:]]-rt' /proc/cmdline|) {
        power_action('reboot', textmode => 1);
        select_kernel('rt');
        $self->select_serial_terminal;
    }

    # switched to RT kernel
    # check if kernel is proper $kernel
    # filter out list of kernel modules
    assert_script_run('uname -r|grep rt', 90, 'Expected rt kernel not found');

    my @kmp_rpms = grep { $_ !~ m/lttng/ && $_ !~ m/kselftests-kmp-rt/ } split("\n", script_output "rpm -qa \*-kmp-rt");
    my @kernel_modules;
    push @kernel_modules, grep { /.*\.ko/ } split("\n", script_output "rpm -ql $_") foreach (@kmp_rpms);
    # load kernel modules
    foreach my $full_module (@kernel_modules) {
        my ($basename, $dir, $suffix) = fileparse($full_module, qr/.ko.*/);
        assert_script_run 'modprobe -v ' . $basename . ' 2>&1 | tee -a /var/log/modprobe.out';
        assert_script_run "modinfo $basename";
        save_screenshot;
    }

    # verify lttng basic tracing functionality
    run_lttng_demo_trace;
    assert_script_run 'killall lttng-sessiond';
    clear_console;
}

sub post_fail_hook {
    my $self = shift;

    select_console 'log-console';

    $self->save_and_upload_log("dmesg", "dmesg.log", {screenshot => 1});
    $self->save_and_upload_log("journalctl --no-pager -o short-precise", "journalctl.log", {screenshot => 1});
    $self->save_and_upload_log('rpm -qa *-kmp-rt', "list_of_kmp_rpms", {screenshot => 1});
    if ((script_run 'test -e /var/log/modprobe.out') == 0) {
        upload_logs '/var/log/modprobe.out';
    }
}

sub test_flags {
    return {milestone => 1};
}

1;
