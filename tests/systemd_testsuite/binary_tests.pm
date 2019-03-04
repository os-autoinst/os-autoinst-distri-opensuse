# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run test executed by TEST-01-BASIC from upstream after openSUSE/SUSE patches.
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>, Thomas Blume <tblume@suse.com>

use base "consoletest";
use warnings;
use strict;
use testapi;
use utils 'zypper_call';
use power_action_utils 'power_action';

sub run {
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

    # add devel tools repo for strace
    my $devel_repo = get_required_var('REPO_SLE_MODULE_DEVELOPMENT_TOOLS');
    zypper_call "ar -c $utils::OPENQA_FTP_URL/" . $devel_repo . " devel-repo";

    # install systemd testsuite
    select_console 'root-console';
    zypper_call "ar $qa_head_repo systemd-testrepo";
    zypper_call '--gpg-auto-import-keys ref';
    zypper_call 'in strace';
    zypper_call 'in systemd-qa-testsuite';

    #run binary tests
    assert_script_run 'cd /var/opt/systemd-tests';
    assert_script_run './run-tests.sh | tee /tmp/testsuite.log', 600;
    assert_screen("systemd-testsuite-binary-tests-summary");
}

sub test_flags {
    return { milestone => 1 };
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    assert_script_run('tar -cjf binary-tests-logs.tar.bz2 /var/opt/systemd-tests/logs');
    upload_logs('binary-tests-logs.tar.bz2');
}


1;
