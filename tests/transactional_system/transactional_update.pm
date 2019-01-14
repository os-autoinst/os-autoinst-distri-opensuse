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
use transactional_system;

# Download files needed for transactional update test
sub get_utt_packages {
    # CaaSP needs an additional repo for testing
    assert_script_run 'curl -O ' . data_url("caasp/utt.repo") if is_caasp 'caasp';

    # Different testfiles for CaaSP and Kubic
    my $tarball = get_var('DISTRI') . '-utt.tgz';
    if (get_var('ARCH') eq 'aarch64') {
        $tarball = get_var('DISTRI') . '-utt-aarch64.tgz';
    }
    assert_script_run 'curl -O ' . data_url("caasp/$tarball");
    assert_script_run "tar xzvf $tarball";
}

# Check that package presence & version is as expected
sub check_package {
    my $stage   = shift // 'no';
    my $package = 'update-test-security';

    if ($stage =~ /in|up/) {
        my $in_ver = rpmver('in');
        if ($stage eq 'in') {
            assert_script_run "rpm -q --qf '%{RELEASE}' $package | grep -x $in_ver";
        }
        elsif ($stage eq 'up') {
            my $rq_ver = script_output("rpm -q --qf '%{RELEASE}' $package");
            die "Bad version: in:$in_ver up:$rq_ver" unless version->declare($in_ver) < version->declare($rq_ver);
        }
    }
    else {
        assert_script_run "! rpm -q $package";
    }
}

sub run {
    script_run "rebootmgrctl set-strategy off";

    get_utt_packages;

    record_info 'Install ptf', 'Install package - snapshot #1';
    trup_call "ptf install" . rpmver('security');
    check_reboot_changes;
    check_package 'in';

    # Find snapshot number for rollback
    my $f    = is_caasp('kubic') ? 1 : 2;
    my $snap = script_output "snapper list | tail -1 | cut -d'|' -f$f | tr -d ' *'";

    record_info 'Update #1', 'Add repository and update - snapshot #2';
    # Only CaaSP needs an additional repo for testing
    assert_script_run 'zypper ar utt.repo' if is_caasp 'caasp';
    trup_call 'cleanup up';
    check_reboot_changes;
    check_package 'up';

    record_info 'Update #2', 'System should be up to date - no changes expected';
    trup_call 'cleanup up';
    check_reboot_changes 0;

    # Check that zypper does not return 0 if update was aborted
    record_info 'Broken pkg', 'Install broken package poo#18644 - snapshot #3';
    if (is_caasp('=4.0')) {
        record_info 'Test skipped - broken image needs breaking again';
    }
    elsif (is_caasp('DVD')) {
        my $broken_pkg = is_caasp('caasp') ? 'trival' : 'broken';
        trup_call "pkg install" . rpmver($broken_pkg);
        check_reboot_changes;
        # Systems with repositories would downgrade on DUP
        my $upcmd = is_caasp('caasp') ? 'dup' : 'up';
        trup_call "cleanup $upcmd", 2;
        check_reboot_changes 0;
    }
    else {
        record_info 'Test skipped on VMX images - poo#31519';
    }

    record_info 'Remove pkg', 'Remove package - snapshot #4';
    trup_call 'pkg remove update-test-security';
    check_reboot_changes;
    check_package;

    record_info 'Rollback', 'Revert to snapshot with initial rpm';
    trup_call "rollback $snap";
    check_reboot_changes;
    check_package 'in';
}

sub test_flags {
    return {no_rollback => 1};
}

1;
