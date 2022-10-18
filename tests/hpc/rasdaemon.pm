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
use utils;

our $file = 'tmpresults.xml';

sub inject_error() {
    # Inject some software errors
    script_run('echo 0x9c00410000080f2b > /sys/kernel/debug/mce-inject/status');
    script_run('echo d5a099a9 > /sys/kernel/debug/mce-inject/addr');
    script_run('echo 4 > /sys/kernel/debug/mce-inject/bank');
    script_run('echo 0xdead57ac1ba0babe > /sys/kernel/debug/mce-inject/misc');
    script_run("echo \"sw\" > /sys/kernel/debug/mce-inject/flags");
}

our $ras_mc_ctl_results;

sub subtestcase_output ($out, $regex, $description) {
    foreach my $line (split('\n', $out)) {
        next if ($line =~ /^\s*$/);
        if (grep /$regex/, $line) {
            $ras_mc_ctl_results = 0;
        }
        else {
            $ras_mc_ctl_results = 1;
        }
        test_case($line, $description, $ras_mc_ctl_results);
    }
}

sub run ($self) {
    # load kernel module
    assert_script_run('modprobe mce-inject') if (is_x86_64 && check_var('VERSION', '15-SP2'));

    my $rt = zypper_call('in rasdaemon');
    test_case('Installation', 'rasdaemon', $rt);

    $rt = assert_script_run('! ras-mc-ctl --status');
    test_case('Check rasdaemon --status', 'drivers are not loaded', $rt);

    # Try to start rasdaemon. May need a restart on aarch64.
    $rt = systemctl('start rasdaemon');
    test_case('Start rasdaemon service', 'service is started', $rt);

    if (systemctl('is-active rasdaemon', ignore_failure => 1)) {
        systemctl('restart rasdaemon');
        record_soft_failure('bsc#1170014 rasdaemon service needed to be restarted.');
        script_retry("systemctl is-active rasdaemon", retry => 9, timeout => 10, delay => 1);
    }

    # Validating output of 'ras-mc-ctl --mainboard'
    my $mainboard_output = script_output('ras-mc-ctl --mainboard');
    record_info('INFO', $mainboard_output);
    test_case('ras-mc-ctl --mainboard', 'Check for errors', $ras_mc_ctl_results);
    subtestcase_output($mainboard_output, 'mainboard', 'Check for errors from ras-mc-ctl --mainboard');

    die('Not expected mainboard - ' . $mainboard_output)
      unless ($mainboard_output =~ /mainboard/);

    # Validating output of 'ras-mc-ctl --summary' with assumption that no errors exists
    my $summary_output = script_output('ras-mc-ctl --summary');
    record_info('INFO', $summary_output);
    test_case('Status ras-mc-ctl --summary', 'Status of the command', $summary_output);
    subtestcase_output($summary_output, 'No .+ errors', 'Check for errors from ras-mc-ctl --summary');

    die('Not expected summary - ' . $summary_output)
      unless ($summary_output =~ /No Memory errors/
        && $summary_output =~ /No PCIe AER errors/ && $summary_output =~ /No MCE errors/);

    # Validating output of 'ras-mc-ctl --errors' with assumption that no errors exists
    my $empty_error_output = script_output('ras-mc-ctl --errors');
    record_info('INFO', $empty_error_output);
    test_case('Status ras-mc-ctl --errors', 'Status of the command', $empty_error_output);
    subtestcase_output($empty_error_output, 'No .+ errors', 'Check for errors from ras-mc-ctl --errors');

    die('Not expected error - ' . $empty_error_output)
      unless ($empty_error_output =~ /Memory errors/
        && $empty_error_output =~ /PCIe AER errors/ && $empty_error_output =~ /No MCE errors/);

    # x86_64 check: Validating output of 'ras-mc-ctl --errors' after MCE error is injected
    if (is_x86_64 && check_var('VERSION', '15-SP2')) {
        inject_error();
        my $error_output = script_output('ras-mc-ctl --errors');
        record_info('INFO', $error_output);

        die('No MCE event recored - ' . $error_output)
          unless ($error_output =~ /MCE events/ && $error_output =~ /status=0x9c00410000080f2b/);
    }

    ##TODO: try to add error injection for ARM
}

sub post_run_hook ($self) {
    pars_results('HPC rasdaemon tests', $file, @all_tests_results);
    parse_extra_log('XUnit', $file);
    $self->SUPER::post_run_hook();
}

sub post_fail_hook ($self) {
    select_serial_terminal;
    $self->export_logs_basic;
}

1;
