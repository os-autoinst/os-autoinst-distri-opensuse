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
use utils 'is_caasp';
use caasp;

# Download files needed for transactional update test
sub get_utt_packages {
    assert_script_run 'curl -O ' . data_url('caasp/utt.tgz');
    assert_script_run 'curl -O ' . data_url('caasp/utt.repo');
    assert_script_run 'tar xzvf utt.tgz';
    send_key "ctrl-l";
}

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

sub check_reboot_changes {
    my $change_expected = shift // 1;

    # Compare currently mounted and default subvolume
    my $time    = time;
    my $mounted = "mnt-$time";
    my $default = "def-$time";
    assert_script_run "mount | grep 'on / ' | egrep -o 'subvolid=[0-9]*' | cut -d'=' -f2 > $mounted";
    assert_script_run "btrfs su get-default / | cut -d' ' -f2 > $default";
    my $change_happened = script_run "diff $mounted $default";

    # If changes are expected check that default subvolume changed
    die "Error during diff" if $change_happened > 1;
    die "Change expected: $change_expected, happeed: $change_happened" if $change_expected != $change_happened;

    # Reboot into new snapshot
    process_reboot 1 if $change_happened;
}

sub run {
    script_run "rebootmgrctl set-strategy off";

    get_utt_packages;

    record_info 'Test #1', 'Install package - snapshot #1';
    trup_call 'ptf install update-test-trival/update-test-security-5-5.3.61.x86_64.rpm';
    check_reboot_changes;
    check_package '5.3.61';

    record_info 'Test #2', 'Add repository and update - snapshot #2';
    assert_script_run 'zypper ar utt.repo';
    trup_call 'reboot cleanup up';
    check_reboot_changes;
    check_package '5.29.2';

    record_info 'Test #3', 'System should be up to date - no changes expected';
    trup_call 'cleanup up';
    check_reboot_changes 0;

    record_info 'Test #4', 'Remove package - snapshot #3';
    trup_call 'pkg remove update-test-security';
    check_reboot_changes;
    check_package;

    record_info 'Test #5', 'Revert to first snapshot we created - snapshot #4';
    # On Hyper-V and Xen PV we modified GRUB to add special framebuffer provisions to scale down,
    # and scale up, respectively, the hypervizor's native screen resolution. As it involved
    # an additional snapshot, magic snapshot numbers below have to be altered properly.
    my $snap = is_caasp('VMX') ? 2 : 3;
    if (check_var('VIRSH_VMM_FAMILY', 'hyperv') || check_var('VIRSH_VMM_TYPE', 'linux')) {
        $snap++;
    }
    trup_call "rollback $snap";
    check_reboot_changes;
    check_package '5.3.61';
}

sub test_flags {
    return {norollback => 1};
}

1;
# vim: set sw=4 et:
