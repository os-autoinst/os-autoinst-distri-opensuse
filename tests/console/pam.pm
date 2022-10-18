# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: bats pam-test pam pam-config snapper perl
# Summary: This PM is to run a suite of tests about PAM, and gets a TAP
#          format result. Four files(pam.sh, pam_test, pam_test.sh,
#          system-default) are included. pam.sh is a "bats" script, and
#          includes 25 tests for PAM. The other files are from the project
#          "pam_test" which can be used to test a PAM stack for authentication
#          and password change. The link: https://github.com/pbrezina/pam-test
#   Steps:
#       - add qa-head repo and install the tool "bats" from qa-head repo.
#         Bats is a TAP-compliant testing framework for Bash.
#       - download "pam_test" dir(automated tests of PAM) from "data" dir
#         on openqa host if "prepare_test_data" perl module desn't run.
#       - run the suite of tests in SUT.
# Maintainer: Jun Wang <jgwang@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils;

sub run {
    my $self = shift;
    select_serial_terminal;

    die "This test module is not enabled for openSUSE Leap yet" if is_leap('<15.3');
    my $version = get_required_var('VERSION');
    if (is_sle()) {
        my $qa_head_repo = "http://download.suse.de/ibs/QA:/Head/" . 'SLE-' . $version;
        zypper_ar("$qa_head_repo", name => 'qa-head-repo');
    }
    zypper_call('install bats pam-test pam pam-config snapper perl');
    if (is_tumbleweed()) {
        zypper_call('in "group(wheel)"');
    }

    # create a snapshot for rollback
    assert_script_run("snapbf=\$(snapper create -p -d 'before pam test')");

    my $pamdir = "/home/bernhard/data/pam_test";
    if (script_run("test -d $pamdir"))
    {
        my $archive = "pam-tests.data";
        assert_script_run("cd; curl -L -v " . autoinst_url . "/data/pam_test > $archive && cpio -id < $archive && mv data pam_test && rm -f $archive");
        $pamdir = "./pam_test";
    }
    my $pam_version = script_output("rpm -q --qf '%{VERSION}\n' pam");
    my $limit_pam_version = '1.5.0';
    my $ret = "";
    my $tap_results = "results.tap";
    if (package_version_cmp($pam_version, $limit_pam_version) >= 0) {
        $ret = script_run("cd $pamdir; prove -v pam.sh >$tap_results", timeout => 180);
    } else {
        $ret = script_run("cd $pamdir; prove -v pam_deprecated.sh >$tap_results", timeout => 180);
    }
    parse_extra_log(TAP => $tap_results);

    # restore the system after running pam.pm
    assert_script_run("snapaf=\$(snapper create -p -d 'after pam test')");
    assert_script_run("snapper -v undochange \$snapbf..\$snapaf");
    assert_script_run("snapper delete \$snapaf \$snapbf", timeout => 180);
    zypper_call('rr qa-head-repo');
    zypper_call('rm bats pam-test');

    die "pam.sh failed, see results.tap for details" if ($ret);
}

1;

