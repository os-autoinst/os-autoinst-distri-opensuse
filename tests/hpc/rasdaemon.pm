# SUSE's openQA tests
#
# Copyright © 2018-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: sanity tests of rasdaemon
#
# rasdaemon is meant to collect various hardware errors. As such the
# test for rasdaemon in virtualized env. has very limitted purpose and
# is meant only as a sanity check for the isolated package.
#
# Purpose of this test: this simple module provide only the sanity check
# to see if:
# - rasdaemon can be installed and started
# - ras-mc-ctl can be used to retrive basic information from the
#   associated database
# - injected error is correctly recorded
#
# Maintainer: Sebastian Chlad <schlad@suse.de>
# Tags: https://fate.suse.com/318824

use base 'hpcbase';
use strict;
use warnings;
use testapi;
use utils;

sub inject_error {
    # load kernel module
    assert_script_run('modprobe mce-inject');
    # Inject some software errors
    script_run('echo 0x9c00410000080f2b > /sys/kernel/debug/mce-inject/status');
    script_run('echo d5a099a9 > /sys/kernel/debug/mce-inject/addr');
    script_run('echo 4 > /sys/kernel/debug/mce-inject/bank');
    script_run('echo 0xdead57ac1ba0babe > /sys/kernel/debug/mce-inject/misc');
    script_run("echo \"sw\" > /sys/kernel/debug/mce-inject/flags");
}

sub run {
    my $self = shift;

    zypper_call('in rasdaemon');

    assert_script_run('! ras-mc-ctl --status');

    # Try to start rasdaemon. May need a restart on aarch64.
    systemctl('start rasdaemon');
    if (systemctl('is-active rasdaemon', ignore_failure => 1)) {
        systemctl('restart rasdaemon');
        record_soft_failure('bsc#1170014 rasdaemon service needed to be restarted.');
        script_retry("systemctl is-active rasdaemon", retry => 9, timeout => 10, delay => 1);
    }

    # Validating output of 'ras-mc-ctl --mainboard'
    my $mainboard_output = script_output('ras-mc-ctl --mainboard');
    record_info('INFO', $mainboard_output);
    die('Not expected mainboard - ' . $mainboard_output)
      unless ($mainboard_output =~ /mainboard/);

    # Validating output of 'ras-mc-ctl --summary' with assumption that no errors exists
    my $summary_output = script_output('ras-mc-ctl --summary');
    record_info('INFO', $summary_output);

    die('Not expected summary - ' . $summary_output)
      unless ($summary_output =~ /No Memory errors/
        && $summary_output =~ /No PCIe AER errors/ && $summary_output =~ /No MCE errors/);

    # Validating output of 'ras-mc-ctl --errors' with assumption that no errors exists
    my $empty_error_output = script_output('ras-mc-ctl --errors');
    record_info('INFO', $empty_error_output);

    die('Not expected error - ' . $empty_error_output)
      unless ($empty_error_output =~ /Memory errors/
        && $empty_error_output =~ /PCIe AER errors/ && $empty_error_output =~ /No MCE errors/);

    # x86_64 check: Validating output of 'ras-mc-ctl --errors' after MCE error is injected
    if (check_var('ARCH', 'x86_64') && check_var('VERSION', '15-SP2')) {
        inject_error();
        my $error_output = script_output('ras-mc-ctl --errors');
        record_info('INFO', $error_output);

        die('No MCE event recored - ' . $error_output)
          unless ($error_output =~ /MCE events/ && $error_output =~ /status=0x9c00410000080f2b/);
    }

    ##TODO: try to add error injection for ARM
}

sub post_fail_hook {
    my ($self) = @_;
    $self->select_serial_terminal;
    $self->export_logs_basic;
}

1;
