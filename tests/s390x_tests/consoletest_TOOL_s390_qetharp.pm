# SUSE’s openQA tests
#
# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: s390 qetharp
# Maintainer: Elif Aslan <elas@linux.vnet.ibm.com>

use base "s390base";
use testapi;
use utils;
use warnings;
use strict;

sub run {
    my $self = shift;
    $self->copy_testsuite('TOOL_s390_qetharp');
    $self->execute_script('10S_cleanup_s390_qetharp.sh');
    $self->execute_script('20S_prepare_s390_qetharp.sh', '1000');
    $self->execute_script('30S_qetharp_test.sh',         '1000');
    $self->execute_script('40S_Ping_Test.sh',            '1000');
    $self->cleanup_testsuite('TOOL_s390_qetharp');

}

sub post_fail_hook {
    my $self = shift;
    $self->export_logs();
}

sub test_flags {
    return {milestone => 1, fatal => 0};
}

1;
