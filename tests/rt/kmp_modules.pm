# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: RT tests
#    test kmp modules & boot RT kernel script for further automated and regression RT tests
#    list of KMP rpms: cluster-md-kmp-rt, gfs2-kmp-rt, dlm-kmp-rt, crash-kmp-rt, oracleasm-kmp-rt
#    lttng-modules-kmp-rt, ocfs2-kmp-rt
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;
use rt_utils 'select_kernel';
use File::Basename 'fileparse';

sub lttng_test {
    my $trace = {
        label     => 'TEST_TRACE',
        output    => '/tmp/sched_trace_example',
        component => 'sched_switch',
        channel   => 'test-channel'
    };

    assert_script_run 'lttng create ' . $trace->{label} . ' -o ' . $trace->{output};
    assert_script_run 'lttng enable-channel --kernel ' . $trace->{channel};
    assert_script_run 'lttng enable-event --kernel -a ' . $trace->{component} . ' -c ' . $trace->{label};
    assert_script_run 'lttng start';
    assert_script_run 'sleep 5';
    assert_script_run 'lttng list ' . $trace->{label};
    assert_script_run 'lttng stop';
    assert_script_run 'lttng destroy -a';
    if ((script_run "test -e $trace->{output}") == 0) {
        assert_script_run "ls -la $trace->{output}" . '/kernel';
        assert_script_run "file $trace->{output}" . '/kernel/' . uc $trace->{label} . '_0';
        assert_script_run "file $trace->{output}" . '/kernel/' . $trace->{channel} . '_0';
    } else {
        die "Trace file \"$trace->{output}\" does not exist!\n";
    }
}

sub run {
    select_console 'root-console';
    # Stop packagekit
    systemctl 'mask packagekit.service';
    systemctl 'stop packagekit.service';
    # allow to load unsupported modules
    script_run 'sed -i s\'/^allow_unsupported_modules 0/allow_unsupported_modules 1/\' /etc/modprobe.d/10-unsupported-modules.conf';
    # install kmp packages
    assert_script_run 'zypper -n in *-kmp-rt', 500;
    type_string "reboot\n";
    select_kernel('rt');
    assert_screen 'generic-desktop';
    reset_consoles;
    select_console 'root-console';
    # check if kernel is proper $kernel
    assert_script_run('uname -r|grep rt', 90, 'Expected rt kernel not found');
    # filter out list of kernel modules
    my @kmp_rpms = grep { !/lttng-modules/ } split("\n", script_output "rpm -qa \*-kmp-rt");
    my @kernel_modules;
    push @kernel_modules, grep { /.*\.ko/ } split("\n", script_output "rpm -ql $_") foreach (@kmp_rpms);
    # load kernel modules
    foreach my $full_module (@kernel_modules) {
        my ($basename, $dir, $suffix) = fileparse($full_module, '.ko');
        assert_script_run 'modprobe -v ' . $basename . ' 2>&1 | tee -a /var/log/modprobe.out';
        assert_script_run "modinfo $basename";
        save_screenshot;
    }
    lttng_test;
    clear_console;
}

sub post_fail_hook {
    my $self = shift;
    $self->save_and_upload_log("dmesg",                 "dmesg.log",        {screenshot => 1});
    $self->save_and_upload_log("journalctl --no-pager", "journalctl.log",   {screenshot => 1});
    $self->save_and_upload_log('rpm -qa *-kmp-rt',      "list_of_kmp_rpms", {screenshot => 1});
    if ((script_run 'test -e /var/log/modprobe.out') == 0) {
        upload_logs '/var/log/modprobe.out';
    }
}

1;
