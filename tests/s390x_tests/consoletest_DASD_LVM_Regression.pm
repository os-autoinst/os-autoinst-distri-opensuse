# SUSE’s openQA tests
#
# Copyright 2018-2019 IBM Corp.
# SPDX-License-Identifier: FSFAP
#
# Summary:  Based on consoletest_setup.pm (console test pre setup, stopping and disabling packagekit, install curl and tar to get logs and so on)
# modified for running the testcase TOOL_s390_vmcp on s390x.
# Maintainer: Elif Aslan <elas@linux.vnet.ibm.com>

use base "s390base";
use testapi;
use utils;

sub run {
    my $self = shift;
    assert_script_run("sed -i '/^\\s*filter/ s/filter/#filter/' /etc/lvm/lvm.conf");
    assert_script_run("rm -rf /root/log && mkdir /root/log && rm -rf /mnt/*");

    my $BASE_PAV = get_var("BASE_PAV");
    my $ALIAS_PAV = get_var("ALIAS_PAV");

    $self->execute_script("01_LVM_Basic_test.sh", "$BASE_PAV $ALIAS_PAV", 600);
    $self->execute_script("02_LVM_Resize_test.sh", "", 600);
    $self->execute_script("03_LVM_Types_stress.sh", "", 600);
    $self->execute_script("04_LVM_snapshot_backup.sh", "", 600);

    assert_script_run("rm -rf /root/log && mkdir /root/log && rm -rf /mnt/*");
}

sub test_flags {
    return {milestone => 1, fatal => 0};
}

1;
# vim: set sw=4 et:
