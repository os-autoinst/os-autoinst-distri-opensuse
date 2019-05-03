# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: library functions for setting up the tests and uploading logs in error case.
# Maintainer: Thomas Blume <tblume@suse.com>


package systemd_testsuite_test;
use base "opensusebasetest";

use strict;
use warnings;
use known_bugs;
use testapi;
use power_action_utils 'power_action';
use utils 'zypper_call';


sub testsuiteinstall {
    my $qa_head_repo = get_var('QA_HEAD_REPO', '');
    if (!$qa_head_repo) {
        if (is_leap('15.0+')) {
            $qa_head_repo = 'https://download.opensuse.org/repositories/devel:/openSUSE:/QA:/Leap:/15/openSUSE_Leap_15.0/';
        }
        elsif (is_sle('15+')) {
            $qa_head_repo = 'http://download.suse.de/ibs/QA:/SLE15/standard/';
        }
        die '$qa_head_repo is not set' unless ($qa_head_repo);
    }

    select_console 'root-console';

    # add devel tools repo and install strace
    my $devel_repo = get_required_var('REPO_SLE_MODULE_DEVELOPMENT_TOOLS');
    zypper_call "ar -c $utils::OPENQA_FTP_URL/" . $devel_repo . " devel-repo";
    zypper_call 'in strace';

    # install systemd testsuite
    zypper_call "ar $qa_head_repo systemd-testrepo";
    zypper_call '--gpg-auto-import-keys ref';
    zypper_call 'in systemd-qa-testsuite';
}

sub testsuiteprepare {
    my ($self, $testname) = @_;
    #prepare test
    select_console 'root-console';
    assert_script_run 'cd /var/opt/systemd-tests';
    assert_script_run "./run-tests.sh $testname --setup 2>&1 | tee /tmp/testsuite.log", 600;
    assert_script_run 'ls -l /etc/systemd/system/testsuite.service';
    #reboot
    power_action('reboot', textmode => 1);
    assert_screen('linux-login', 600);
    type_string "root\n";
    wait_still_screen 3;
    type_password;
    wait_still_screen 3;
    send_key 'ret';
}

sub post_fail_hook {
    my ($self) = @_;
    #upload logs from given testname
    $self->tar_and_upload_log('/var/opt/systemd-tests/logs', '/tmp/systemd_testsuite-logs.tar.bz2');
}


1;
