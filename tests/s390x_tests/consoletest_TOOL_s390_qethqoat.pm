# SUSE’s openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary:  Based on consoltest_setup.pm (console test pre setup, stopping and disabling packagekit, install curl and tar to get logs and so on)
# modified for running the testcase TOOL_s390_CHCHP on s390x.
# Maintainer: Elif Aslan <elas@linux.vnet.ibm.com>

use base "s390base";
use testapi;
use utils;
use warnings;
use strict;

sub run {
    my $self = shift;
    $self->copy_testsuite('TOOL_s390_qethqoat');
    $self->execute_script('10S_cleanup_qethqoat.sh');
    $self->execute_script('20S_prepare_qethqoat.sh');
    $self->execute_script('30S_test_qethqoat.sh');
    $self->cleanup_testsuite('TOOL_s390_qethqoat');

}

sub post_fail_hook {
    my $self = shift;
    $self->export_logs();
}

sub test_flags {
    return {milestone => 1, fatal => 0};
}

1;
# vim: set sw=4 et:
