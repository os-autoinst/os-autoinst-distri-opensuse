# SUSE’s openQA tests
#
# Copyright 2018-2019 IBM Corp.
# SPDX-License-Identifier: FSFAP

# Summary: s390 qetharp
# Maintainer: Elif Aslan <elas@linux.vnet.ibm.com>

use base "s390base";
use testapi;
use utils;

sub run {
    my $self = shift;
    $self->copy_testsuite('TOOL_s390_qetharp');
    $self->execute_script('10S_cleanup_s390_qetharp.sh');
    $self->execute_script('20S_prepare_s390_qetharp.sh', '1000');
    $self->execute_script('30S_qetharp_test.sh', '1000');
    $self->execute_script('40S_Ping_Test.sh', '1000');
    $self->cleanup_testsuite('TOOL_s390_qetharp');

}

sub test_flags {
    return {milestone => 1, fatal => 0};
}

1;
