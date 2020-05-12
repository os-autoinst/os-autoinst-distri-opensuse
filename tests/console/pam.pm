# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
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
use utils;
use version_utils qw(is_leap is_sle);

sub run {
    select_console 'root-console';

    die "This test module is not enabled for openSUSE Leap yet" if is_leap();
    my $version = get_required_var('VERSION');
    if (is_sle()) {
        my $qa_head_repo = "http://download.suse.de/ibs/QA:/Head/" . 'SLE-' . $version;
        zypper_ar("$qa_head_repo", name => 'qa-head-repo');
    }
    zypper_call('install bats pam-test pam pam-config snapper');

    # create a snapshot for rollback
    assert_script_run("snapbf=\$(snapper create -p -d 'before pam test')");

    my $pamdir = "/home/bernhard/data/pam_test";
    if (script_run("test -d $pamdir"))
    {
        my $archive = "pam-tests.data";
        assert_script_run("cd; curl -L -v " . autoinst_url . "/data/pam_test > $archive && cpio -id < $archive && mv data pam_test && rm -f $archive");
        $pamdir = "./pam_test";
    }

    my $tap_results = "results.tap";
    my $ret         = script_run("cd $pamdir; prove -v pam.sh >$tap_results", timeout => 180);
    parse_extra_log(TAP => $tap_results);

    # restore the system after running pam.pm
    assert_script_run("snapaf=\$(snapper create -p -d 'after pam test')");
    assert_script_run("snapper -v undochange \$snapbf..\$snapaf");
    assert_script_run("snapper delete \$snapaf \$snapbf");
    zypper_call('rr qa-head-repo');

    die "pam.sh failed, see results.tap for details" if ($ret);
}

1;

