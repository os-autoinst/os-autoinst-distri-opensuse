# SUSE’s openQA tests
#
# Copyright 2018-2019 IBM Corp.
# SPDX-License-Identifier: FSFAP
#
# Summary:  Based on consoletest_setup.pm (console test pre setup, stopping and disabling packagekit, install curl and tar to get logs and so on)
# modified for running the testcase MEMORY_memtester on s390x.
# Maintainer: Elif Aslan <elas@linux.vnet.ibm.com>

use base "s390base";
use testapi;
use utils;

sub run {
    my $self = shift;
    $self->copy_testsuite('MEMORY_memtester');
    zypper_call "in gcc";
    assert_script_run "tar -xzf memtester*tar.gz && rm -rf memtester*tar.gz";
    assert_script_run "cd memtester*&& make && make install && cd ..";

    $self->execute_script('runMemtester.sh', '100M 3', 600);

    assert_script_run "rm -f /usr/bin/memtester; rm -rf /root/MEMORY_memtester";
}

sub test_flags {
    return {milestone => 1, fatal => 0};
}

1;
# vim: set sw=4 et:
