# SUSE’s openQA tests
#
# Copyright 2018-2019 IBM Corp.
# SPDX-License-Identifier: FSFAP
#
# Summary:  Based on consoletest_setup.pm (console test pre setup, stopping and disabling packagekit, install curl and tar to get logs and so on)
# modified for running the testcase TOOL_s390_vmconvert on s390x.
# Maintainer: Elif Aslan <elas@linux.vnet.ibm.com>

use base "s390base";
use testapi;
use utils;

sub run {
    my $self = shift;
    $self->copy_testsuite('TOOL_s390_vmconvert');

    my $REPO_SUSE = get_var('REPO_SUSE');
    assert_script_run "echo -e \"$REPO_SUSE\" > /etc/zypp/repos.d/sles.repo";
    assert_script_run "cat /etc/zypp/repos.d/sles.repo";

    zypper_call "in kernel-default-debuginfo";
    assert_script_run "[ -f /boot/vmlinux-4.4.73-5-default.gz ] && gunzip /boot/vmlinux-4.4.73-5-default.gz || true";

    $self->execute_script('vmcon.sh', '', 3000);

}

sub test_flags {
    return {milestone => 1, fatal => 0};
}

1;
# vim: set sw=4 et:
