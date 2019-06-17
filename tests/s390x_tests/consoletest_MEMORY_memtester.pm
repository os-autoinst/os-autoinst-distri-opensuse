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
# modified for running the testcase MEMORY_memtester on s390x.
# Maintainer: Elif Aslan <elas@linux.vnet.ibm.com>

use base "s390base";
use testapi;
use utils;
use warnings;
use strict;

sub run {
    my $self = shift;
    $self->copy_testsuite('MEMORY_memtester');
    zypper_call "in gcc";
    assert_script_run "tar -xzf memtester*tar.gz && rm -rf memtester*tar.gz";
    assert_script_run "cd memtester*&& make && make install && cd ..";

    $self->execute_script('runMemtester.sh', '100M 3', 600);

    assert_script_run "rm -f /usr/bin/memtester; rm -rf /root/MEMORY_memtester";
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
