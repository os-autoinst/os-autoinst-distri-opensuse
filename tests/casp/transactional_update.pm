# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test transactional updates
#   Installs & remove ptf, update, rollback
#   Check that system was rebooted and mounted snapshot changed
#   Check that expected package version match
# Maintainer: Martin Kravec <mkravec@suse.com>
# Tags: poo#14444

use strict;
use base "opensusebasetest";
use testapi;
use utils 'is_casp';
use caasp;

# Check that package presence & version is as expected
sub check_package {
    my $version = shift;
    my $package = 'update-test-security';

    if ($version) {
        assert_script_run "rpm -qi $package | grep ^Release.*$version";
    }
    else {
        assert_script_run "! rpm -qi $package";
    }
}

# Reboot and check that mounted snapshot differ if we expect the change
sub check_reboot_changes {
    my $nochange = shift;

    my $svbf = script_output 'mount | grep "on / " | grep -o "subvolid=.*snapshot"';
    process_reboot 1;
    my $svaf = script_output 'mount | grep "on / " | grep -o "subvolid=.*snapshot"';

    die "Unexpected snapshot $svbf : $svaf is mounted" unless ($svbf eq $svaf) == $nochange;
}

sub run() {
    script_run "rebootmgrctl set-strategy off";

    # Download files needed for transactional update test
    assert_script_run 'curl -O ' . data_url('caasp/utt.tgz');
    assert_script_run 'curl -O ' . data_url('caasp/utt.repo');
    assert_script_run 'tar xzvf utt.tgz';

    # Install PTF - snapshot #1
    trup_call 'ptf install update-test-trival/update-test-security-5-5.3.61.x86_64.rpm';
    check_reboot_changes;
    check_package '5.3.61';

    # Add repository and update - snapshot#2
    assert_script_run 'zypper ar utt.repo';
    trup_call 'reboot cleanup up';
    check_reboot_changes;
    check_package '5.4.2';

    # System should be up to date - no changes expected
    trup_call 'cleanup up';
    check_reboot_changes 1;

    # Remove PTF - snapshot #3
    trup_call 'ptf remove update-test-security';
    check_reboot_changes;
    check_package;

    # Revert to first snapshot that we created
    my $snap = is_casp('VMX') ? 2 : 3;
    trup_call "rollback $snap";
    check_reboot_changes;
    check_package '5.3.61';
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:
