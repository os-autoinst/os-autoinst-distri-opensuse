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
use version_utils 'is_caasp';
use caasp;

# Download files needed for transactional update test
sub get_utt_packages {
    # CaaSP needs an additional repo for testing
    assert_script_run 'curl -O ' . data_url("caasp/utt.repo") if is_caasp 'caasp';

    # Different testfiles for CaaSP and Kubic
    my $tarball = get_var('DISTRI') . '-utt.tgz';
    assert_script_run 'curl -O ' . data_url("caasp/$tarball");
    assert_script_run "tar xzvf $tarball";
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

    record_info 'Install ptf', 'Install package - snapshot #1';
    trup_call "ptf install" . rpmver('security');
    check_reboot_changes;
    check_package rpmver('in');

    record_info 'Update #1', 'Add repository and update - snapshot #2';
    # Only CaaSP needs an additional repo for testing
    assert_script_run 'zypper ar utt.repo' if is_caasp 'caasp';
    trup_call 'cleanup up';
    check_reboot_changes;
    check_package rpmver('up');

    record_info 'Update #2', 'System should be up to date - no changes expected';
    trup_call 'cleanup up';
    check_reboot_changes 0;

    # Check that zypper does not return 0 if update was aborted
    record_info 'Broken pkg', 'Install broken package - snapshot #3';
    if (is_caasp('caasp') && is_caasp('DVD')) {
        my $broken_pkg = is_caasp('caasp') ? 'trival' : 'broken';
        trup_call "pkg install" . rpmver($broken_pkg);
        check_reboot_changes;
        trup_call 'cleanup dup', 2;
        check_reboot_changes 0;
    }
    else {
        record_info 'Test skipped on openSUSE Kubic & VMX images - poo#31519';
    }

    record_info 'Remove pkg', 'Remove package - snapshot #4';
    trup_call 'pkg remove update-test-security';
    check_reboot_changes;
    check_package;

    # On Hyper-V and Xen PV we modified GRUB to add special framebuffer provisions to scale down,
    # and scale up, respectively, the hypervizor's native screen resolution. As it involved
    # an additional snapshot, magic snapshot numbers below have to be altered properly.
    record_info 'Rollback', 'Revert to first snapshot we created - snapshot #5';
    my $snap = is_caasp('VMX') ? 2 : 3;
    if (check_var('VIRSH_VMM_FAMILY', 'hyperv') || check_var('VIRSH_VMM_TYPE', 'linux')) {
        $snap++;
    }
    # overlayfs test creates new snapshot
    $snap++;

    trup_call "rollback $snap";
    check_reboot_changes;
    check_package rpmver('in');
}

sub test_flags {
    return {norollback => 1};
}

1;
# vim: set sw=4 et:
