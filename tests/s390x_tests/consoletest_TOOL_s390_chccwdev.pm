# SUSE’s openQA tests
#
# Copyright 2018-2019 IBM Corp.
# SPDX-License-Identifier: FSFAP
#
# Summary:  Based on consoletest_setup.pm (console test pre setup, stopping and disabling packagekit, install curl and tar to get logs and so on)
# modified for running the testcase TOOL_s390_chccwdev on s390x.
# Maintainer: Elif Aslan <elas@linux.vnet.ibm.com>

use base "s390base";
use testapi;
use utils;

sub run {
    my $self = shift;
    $self->copy_testsuite("TOOL_s390_chccwdev");
    my $DASD1 = get_var("DASD1");
    my $DASD2 = get_var("DASD2");
    $self->execute_script("chccwdev_main.sh", "$DASD1 $DASD2", 1800);
    $self->execute_script("safeoffline.sh", "$DASD1 tbd", 3600);
}

sub test_flags {
    return {milestone => 1, fatal => 0};
}

1;
# vim: set sw=4 et:
