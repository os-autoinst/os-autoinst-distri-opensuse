# SUSE’s openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary:  Based on consoletest_setup.pm (console test pre setup, stopping and disabling packagekit, install curl and tar to get logs and so on)
# modified for running the testcase KERNEL_LSCPU_CHCPU on s390x.
# Maintainer: Elif Aslan <elas@linux.vnet.ibm.com>

use base "s390base";
use testapi;
use utils;
use warnings;
use strict;

sub run {
    my $self = shift;
    $self->copy_testsuite('KERNEL_LSCPU_CHCPU');
    $self->execute_script('test_lscpu.sh',               '',      600);
    $self->execute_script('test_chcpu.sh',               '',      600);
    $self->execute_script('test_lscpu_chcpu_invalid.sh', '',      300);
    $self->execute_script('lscpu_chcpu_kernel_parm.sh',  'start', 300);
    $self->execute_script('lscpu_chcpu_kernel_parm.sh',  'test1', 300);
    $self->execute_script('lscpu_chcpu_kernel_parm.sh',  'test2', 300);

    power_action('reboot', observe => 1, keepconsole => 1);
    $self->wait_boot(bootloader_time => 300);
    select_console('root-console');

    assert_script_run "cd KERNEL_LSCPU_CHCPU";
    $self->execute_script('lscpu_chcpu_kernel_parm.sh', 'check', 300);
    $self->execute_script('lscpu_chcpu_kernel_parm.sh', 'test3', 300);
    $self->execute_script('lscpu_chcpu_kernel_parm.sh', 'end',   300);
}

sub post_fail_hook {
    my $self = shift;
    #    $self->export_logs();
}

sub test_flags {
    return {milestone => 1, fatal => 0};
}

1;
# vim: set sw=4 et:
