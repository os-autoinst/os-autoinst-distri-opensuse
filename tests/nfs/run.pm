# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run tests
# Maintainer: Yong Sun <yosun@suse.com>
package run;

use 5.018;
use strict;
use warnings;
use base 'opensusebasetest';
use File::Basename;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use power_action_utils 'power_action';

sub pynfs_server_test_all {
    my $folder = get_required_var('PYNFS');

    assert_script_run("cd ./$folder");
    script_run('./testserver.py -v --rundeps --hidepass --json results.json --maketree localhost:/exportdir all', 3600);
}

sub run {
    select_serial_terminal;

    if (get_var("PYNFS")) {
        script_run('cd ~/pynfs');
        pynfs_server_test_all;
    }
    elsif (get_var("CTHON04")) {
        script_run('cd ~/cthon04');
        script_run('./runtests -b -t /exportdir | tee result_basic_test.txt');
        script_run('./runtests -g -t /exportdir | tee result_general_test.txt');
        script_run('./runtests -s -t /exportdir | tee result_special_test.txt');
        script_run('./runtests -l -t /exportdir | tee result_lock_test.txt');
    }
}

1;

=head1 Configuration

=head2 Example PYNFS configuration for SLE:

BOOT_HDD_IMAGE=1
DESKTOP=textmode
HDD_1=SLES-%VERSION%-%ARCH%-%BUILD%@%MACHINE%-minimal_with_sdk%BUILD_SDK%_installed.qcow2
PYNFS=nfs4.0
UEFI_PFLASH_VARS=SLES-%VERSION%-%ARCH%-%BUILD%@%MACHINE%-minimal_with_sdk%BUILD_SDK%_installed-uefi-vars.qcow2
START_AFTER_TEST=create_hdd_minimal_base+sdk

=head2 PYNFS_GIT_URL

Overrides the official pynfs repository URL.

=head2 PYNFS_RELEASE

This can be set to a release tag, commit hash, branch name or whatever else Git
will accept.

If not set, then the default clone action will be performed, which probably
means the latest master branch will be used.

=head2 Example CTHON04 configuration for SLE:

BOOT_HDD_IMAGE=1
DESKTOP=textmode
HDD_1=SLES-%VERSION%-%ARCH%-%BUILD%@%MACHINE%-minimal_with_sdk%BUILD_SDK%_installed.qcow2
CTHON04=1
NFSVERSION=3
UEFI_PFLASH_VARS=SLES-%VERSION%-%ARCH%-%BUILD%@%MACHINE%-minimal_with_sdk%BUILD_SDK%_installed-uefi-vars.qcow2
START_AFTER_TEST=create_hdd_minimal_base+sdk

=head2 NFSVERSION

Fill 3 or 4 in this parameter to set test NFSv3 or NFSv4.

=head2 CTHON04_GIT_URL

Similar PYNFS_GIT_URL, it overrides the official cthon04 repository URL.

=cut
