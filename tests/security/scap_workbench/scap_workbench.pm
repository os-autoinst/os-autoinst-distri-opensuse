# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test SCAP Workbench (scap-workbench) works
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#110256, jsc#SLE-24111, poo#110647

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub authentication_required {
    if (check_screen('Authentication-Required', timeout => 120)) {
        type_password($testapi::password);
        assert_and_click('authenticate');
    }
}

sub run {
    select_console 'root-console';

    # Install needed packages
    zypper_call('in scap-workbench', timeout => 180);

    # Turn to x11 and start 'xterm'
    select_console('x11');
    x11_start_program('xterm');

    # Start scap-workbench
    record_info('Start scap-workbench');
    enter_cmd('scap-workbench &');
    assert_screen('scap-workbench-started', timeout => 120);

    # Load 'SLE15' content if the system is sle
    if (is_sle()) {
        record_info('Load SLE15');
        assert_and_click('scap-workbench-Select-content-to-load');
        assert_and_click('scap-workbench-Sle15');
    }
    assert_and_click('scap-workbench-Load-Content');

    # Customize profile
    record_info('Customize profile');
    assert_and_click('scap-workbench-Customize');
    assert_and_click('scap-workbench-Customize-Profile-OK');
    assert_and_click('scap-workbench-Customize-OK');

    # Scan system
    record_info('Scan system');
    assert_and_click('scap-workbench-Scan');
    authentication_required();
    if (is_sle()) {
        assert_and_click('scap-workbench-Diagnostics-Close', timeout => 300);
        assert_screen('scap-workbench-Scan-Done');
    }

    # Show report after 'Scan'
    record_info('Show scan report');
    assert_and_click('scap-workbench-Show-Report');
    # Firefox will be started automatically
    assert_screen('scap-workbench-OpenSCAP-Evaluation-Report', timeout => 120);
    assert_and_click('scap-workbench-OpenSCAP-Evaluation-Report-Close');

    # Save Results after 'Scan': XCCDF, ARF, HTML
    record_info('Generate scan files');
    my @scan_steps = ('XCCDF', 'ARF', 'HTML');
    foreach my $step (@scan_steps) {
        assert_and_click('scap-workbench-Save-Results');
        assert_and_click("scap-workbench-Save-Results-$step");
        assert_and_click("scap-workbench-Save-Results-$step-Save");
    }

    # Generate remediation: bash, ansible, puppet
    record_info('Generate remediation files');
    my @remed_steps = ('bash', 'ansible', 'puppet');
    foreach my $step (@remed_steps) {
        assert_and_click('scap-workbench-Generate-remediation');
        assert_and_click("scap-workbench-Generate-remediation-$step");
        assert_and_click('scap-workbench-Generate-remediation-Save');
        assert_and_click('scap-workbench-Generate-remediation-Save-OK');
    }

    # Clear the 'Scan' results
    assert_and_click('scap-workbench-Scan-Clear');

    # Dry run
    record_info('Dry run');
    assert_and_click('scap-workbench-Dry-run-unchecked');
    assert_and_click('scap-workbench-Scan');
    authentication_required();
    assert_and_click('scap-workbench-Dry-run-Close');
    assert_and_click('scap-workbench-Dry-run-checked');

    # Remediate system
    record_info('Remediate');
    assert_and_click('scap-workbench-Remediate-unchecked');
    assert_and_click('scap-workbench-Scan');
    authentication_required();
    if (is_sle()) {
        assert_and_click('scap-workbench-Diagnostics-Close', timeout => 300);
        assert_screen('scap-workbench-Scan-Done');
    }

    # Turn to root console
    select_console('root-console');

    # Check the 'Scan' 'report' files are saved: XCCDF, ARF, HTML
    # Check the 'Remediate' files are saved: bash, ansible, puppet
    my $system = is_sle() ? "sle15" : "opensuse";
    my @files = (
        "ssg-$system-ds-xccdf.results.xml",
        "ssg-$system-ds-arf.xml",
        "ssg-$system-ds-xccdf.report.html",
        'remediation.sh',
        'remediation.pp'
    );
    foreach my $file (@files) {
        assert_script_run("ls /home/bernhard/ | grep $file");
    }
}

sub test_flags {
    return {always_rollback => 1};
}

1;
