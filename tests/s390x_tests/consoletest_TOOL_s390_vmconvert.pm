# SUSE’s openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary:  Based on consoletest_setup.pm (console test pre setup, stopping and disabling packagekit, install curl and tar to get logs and so on)
# modified for running the testcase TOOL_s390_vmconvert on s390x.
# Maintainer: Elif Aslan <elas@linux.vnet.ibm.com>

use base "s390base";
use testapi;
use utils;
use warnings;
use strict;

sub run {
    my $self = shift;
    $self->copy_testsuite('TOOL_s390_vmconvert');

    my $REPO_SUSE = get_var('REPO_SUSE');
    assert_script_run "echo -e \"$REPO_SUSE\" > /etc/zypp/repos.d/sles.repo";
    assert_script_run "cat /etc/zypp/repos.d/sles.repo";

    assert_script_run("zypper in -y kernel-default-debuginfo", timeout => 900);
    assert_script_run "[ -f /boot/vmlinux-4.4.73-5-default.gz ] && gunzip /boot/vmlinux-4.4.73-5-default.gz || true";

    $self->execute_script('vmcon.sh', '', 3000);

}

sub post_fail_hook {
    my $self = shift;
    #    $self->export_logs();
}

sub test_flags {
    return {milestone => 1, fatal => 0};
}

1;
# vim: set sw=4 et:
