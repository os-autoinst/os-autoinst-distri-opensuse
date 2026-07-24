# SUSE's openQA tests
#
# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
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
# Maintainer: Kernel QE <kernel-qa@suse.de>
# Tags: https://fate.suse.com/318824

use Mojo::Base 'hpcbase', -signatures;
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Architectures;
use Utils::Logging 'export_logs_basic';
use utils;
use package_utils 'install_package';
use version_utils qw(is_sle is_tumbleweed);


sub inject_error() {
    # Inject some software errors
    script_run('echo 0x9c00000000000000 > /sys/kernel/debug/mce-inject/status');
    script_run('echo 0xd5a099a9 > /sys/kernel/debug/mce-inject/addr');
    script_run('echo 0xdead57ac1ba0babe > /sys/kernel/debug/mce-inject/misc');
    script_run("echo \"sw\" > /sys/kernel/debug/mce-inject/flags");
    script_run('echo 4 > /sys/kernel/debug/mce-inject/bank');
}


sub run {
    select_serial_terminal();

    # load kernel module
    assert_script_run('modprobe mce-inject') if is_x86_64;

    install_package('rasdaemon', trup_apply => 1);

    # Skip functional tests on ppc64le and Tumbleweed. It is not fully supported,
    # we are interested in installation only
    return if (is_ppc64le && is_tumbleweed);

    # The latest ras-mc-ctl checks switched from /proc/modules/ to /sys/module/
    # which contains BOTH built-in and loadable modules. We now record the status instead
    # of asserting a failure, ensuring compatibility with both old and new tool versions.
    my $status_output = script_output('ras-mc-ctl --status', proceed_on_failure => 1);
    record_info('ras-status', $status_output);
    die 'unexpected ras-mc-ctl --status output: ' . $status_output
      unless $status_output =~ /drivers (are |not )loaded/;

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
    if (is_x86_64 && (is_sle('=15-sp2') || is_sle('=15-sp6') || is_tumbleweed)) {
        inject_error();
        my $error_output = script_output('ras-mc-ctl --errors');
        record_info('INFO', $error_output);
        die('No MCE event recored - ' . $error_output)
          unless ($error_output =~ /MCE events/ && $error_output =~ /status=0x9c00000000000000/);
    }
}

sub post_run_hook ($self) {
    $self->SUPER::post_run_hook();
}

sub post_fail_hook ($self) {
    select_serial_terminal;
    export_logs_basic;
}

1;
