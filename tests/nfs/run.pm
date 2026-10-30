# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run tests
# Maintainer: Yong Sun <yosun@suse.com>
package run;

use 5.018;
use Mojo::Base 'opensusebasetest';
use File::Basename;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use power_action_utils 'power_action';
use LTP::WhiteList;
use LTP::utils 'prepare_whitelist_environment';

# Return the pynfs test codes marked with skip in PYNFS_KNOWN_ISSUES
sub pynfs_skipped_tests {
    my ($version) = @_;
    my $issues = get_var('PYNFS_KNOWN_ISSUES') or return ();
    my $whitelist = LTP::WhiteList->new($issues);
    my $environment = prepare_whitelist_environment();
    $environment->{kernel} = script_output('uname -r');
    $environment->{test_variant} = $version;

    my @skipped;
    for my $test (sort $whitelist->list_skipped_tests($environment, 'pynfs')) {
        # testserver.py aborts the whole run on an unknown code
        if (script_run("grep -rqw 'CODE: $test' .")) {
            record_info('Unknown code', "$test is not a pynfs $version test, not skipping it", result => 'softfail');
            next;
        }
        my $entry = $whitelist->find_whitelist_entry($environment, 'pynfs', $test);
        my $message = $entry->{message} // '';
        record_info('Known issue', "Skipping $test" . ($message ? ": $message" : ''));
        push @skipped, $test;
    }
    return @skipped;
}

sub run {
    select_serial_terminal;

    if (get_var("PYNFS")) {
        my $version = get_required_var('NFSVERSION');

        my $pynfs_dir = get_var('PYNFS_INSTALL', 'from_repo') eq 'from_repo' ? '/usr/lib/pynfs' : '~/pynfs';

        assert_script_run("cd $pynfs_dir/nfs$version");
        # A code prefixed with "no" excludes the test, the last match wins
        my $tests = join(' ', 'all', map { "no$_" } pynfs_skipped_tests($version));
        # The installed test directory is read-only on transactional systems
        script_run("./testserver.py -v --rundeps --hidepass --json /var/tmp/pynfs-results.json --maketree localhost:/var/exportdir $tests", 3600);
    }
    elsif (get_var("CTHON04")) {
        my $cthon04_dir = get_var('CTHON04_INSTALL', 'from_repo') eq 'from_repo' ? '/usr/lib/cthon04' : '~/cthon04';

        # The installed test directory is read-only on transactional systems
        assert_script_run('mkdir -p /var/tmp/cthon04');
        script_run("cd $cthon04_dir");
        script_run('./runtests -b -t /var/exportdir | tee /var/tmp/cthon04/result_basic_test.txt');
        script_run('./runtests -g -t /var/exportdir | tee /var/tmp/cthon04/result_general_test.txt');
        script_run('./runtests -s -t /var/exportdir | tee /var/tmp/cthon04/result_special_test.txt');
        script_run('./runtests -l -t /var/exportdir | tee /var/tmp/cthon04/result_lock_test.txt');
    }
}

1;

=head1 Configuration

=head2 Example PYNFS configuration for SLE:

BOOT_HDD_IMAGE=1
DESKTOP=textmode
HDD_1=SLES-%VERSION%-%ARCH%-%BUILD%@%MACHINE%-minimal_with_sdk%BUILD_SDK%_installed.qcow2
PYNFS=1
NFSVERSION=4.0
UEFI_PFLASH_VARS=SLES-%VERSION%-%ARCH%-%BUILD%@%MACHINE%-minimal_with_sdk%BUILD_SDK%_installed-uefi-vars.qcow2
START_AFTER_TEST=create_hdd_minimal_base+sdk

=head2 PYNFS_KNOWN_ISSUES

URL of the known issues file. The suite name is "pynfs", the test name is the
pynfs test code and test_variant matches NFSVERSION. Tests with skip set are
excluded from the run, failures of the other matching tests are soft failures.

=head2 PYNFS_GIT_URL

Overrides the official pynfs repository URL.

=head2 PYNFS_RELEASE

This can be set to a release tag, commit hash, branch name or whatever else git
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

Overrides the official cthon04 repository URL.

=head2 CTHON04_RELEASE

This can be set to a release tag, commit hash, branch name or whatever else git
will accept.

If not set, then the default clone action will be performed, which probably
means the latest master branch will be used.

=cut
