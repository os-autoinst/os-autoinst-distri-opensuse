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
# modified for running the testcase TOOL_s390_chccwdev on s390x.
# Maintainer: Elif Aslan <elas@linux.vnet.ibm.com>

use base "s390base";
use testapi;
use utils;
use warnings;
use strict;

sub run {
    my $self = shift;
    $self->copy_testsuite("TOOL_s390_chccwdev");
    my $DASD1 = get_var("DASD1");
    my $DASD2 = get_var("DASD2");
    $self->execute_script("chccwdev_main.sh", "$DASD1 $DASD2", 1800);
    $self->execute_script("safeoffline.sh",   "$DASD1 tbd",    3600);

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
