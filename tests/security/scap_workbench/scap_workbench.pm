# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test SCAP Workbench (scap-workbench) works
# Maintainer: QE Security <none@suse.de>
# Tags: poo#110256, jsc#SLE-24111, poo#110647

use base 'opensusebasetest';
use testapi;
use utils;
use version_utils 'is_sle';

sub authentication_required {
    if (check_screen('Authentication-Required', timeout => 240)) {
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

    # Load 'SLE15' content if the system is sle, otherwise opensuse
    my $system = is_sle() ? "sle15" : "opensuse";
    my $content_to_load = "/usr/share/xml/scap/ssg/content/ssg-$system-ds.xml";

    # Start scap-workbench
    record_info('Start scap-workbench');
    enter_cmd("scap-workbench $content_to_load &");
    # Customize profile
    record_info('Customize profile');
    wait_still_screen();
    wait_screen_change {
        assert_and_click('scap-workbench-Customize', timeout => 180);
    };
    # close the customization dialog
    wait_screen_change {
        assert_and_click('scap-workbench-Customize-Profile-OK', timeout => 180);
    };
    # close the right panel that should appear displaying the customized profile.
    # if it's not present, select first element in order to show it
    if (!check_screen 'scap-workbench-Customize-OK') {
        send_key 'tab';
    }
    wait_screen_change {
        assert_and_click('scap-workbench-Customize-OK', timeout => 180);
    };
    wait_still_screen();
    # Scan system
    record_info('Scan system');
    assert_and_click('scap-workbench-Scan');
    authentication_required();
    wait_still_screen();
    # SLE file has 3x size so requires more time to scan
    if (is_sle()) {
        assert_and_click('scap-workbench-Diagnostics-Close', timeout => 600);
        assert_screen('scap-workbench-Scan-Done', timeout => 300);
    }

    # Show report after 'Scan'
    record_info('Show scan report');
    assert_and_click('scap-workbench-Show-Report');
    # Firefox will be started automatically
    assert_screen('scap-workbench-OpenSCAP-Evaluation-Report', timeout => 180);
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
        assert_and_click('scap-workbench-Diagnostics-Close', timeout => 600);
        assert_screen('scap-workbench-Scan-Done', timeout => 300);
    }

    # Turn to root console
    select_console('root-console');

    # Check the 'Scan' 'report' files are saved: XCCDF, ARF, HTML
    # Check the 'Remediate' files are saved: bash, ansible, puppet
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
