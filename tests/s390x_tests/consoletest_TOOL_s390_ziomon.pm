# SUSE’s openQA tests
#
# Copyright 2018-2019 IBM Corp.
# SPDX-License-Identifier: FSFAP
#
# Summary:  Based on consoltest_setup.pm (console test pre setup, stopping and disabling packagekit, install curl and tar to get logs and so on)
# modified for running the testcase TOOL_s390_ZIOMON on s390x.
# Maintainer: Elif Aslan <elas@linux.vnet.ibm.com>

use base "s390base";
use testapi;
use utils;

sub run {
    my $self = shift;
    my $LUN = get_var('PARM_LUN');
    my $WWPN = get_var('PARM_WWPN');
    my $ADAPTER = get_var('PARM_ADAPTER');
    $self->copy_testsuite('TOOL_s390_ziomon');
    assert_script_run('chmod +x ziomon_basic.pl');
    $self->execute_script('ziomon_basic.pl', "$ADAPTER $WWPN $LUN", 1000);
    $self->cleanup_testsuite('TOOL_s390_ziomon');
}

sub test_flags {
    return {milestone => 1, fatal => 0};
}

1;
