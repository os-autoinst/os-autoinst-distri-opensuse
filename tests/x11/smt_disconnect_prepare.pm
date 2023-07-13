# SUSE's openQA tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: nfs-kernel-server nfs-client iproute2 SUSEConnect
# Summary: Do some prepare for internal and external SMT on disconnect SMT case
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use migration;
use mm_network;
use mm_tests;
use suseconnect_register;

sub run {
    my ($self) = @_;
    select_console("root-console");
    if (check_var("SMT", "internal")) {
        configure_static_network('10.0.2.100/24');
    }
    else {
        configure_static_network('10.0.2.111/24');
    }

    # server running smt must be registered
    command_register(get_required_var('VERSION'));

    systemctl 'stop ' . $self->firewall;

    # external smt should enalbe nfs and share a file to simulate a mobile disk
    if (check_var("SMT", "external")) {
        systemctl("enable nfs-server.service");
        systemctl("start nfs-server.service");
        systemctl("enable nfs.service");
        systemctl("start nfs.service");
        assert_script_run("mkdir -p \/mnt\/Mobile-disk");
        assert_script_run("chmod 777 \/mnt\/Mobile-disk");
        assert_script_run("echo \"\/mnt\/Mobile-disk *(rw,no_root_squash,sync,no_subtree_check,crossmnt,nohide)\" >> \/etc\/exports");
        assert_script_run("exportfs -ar");
    }
    else {
        systemctl("enable nfs.service");
        systemctl("start nfs.service");
        assert_script_run("mkdir -p \/mnt\/Mobile-disk");
    }

    # internal smt should close network to simulate a restricted network
    if (check_var("SMT", "internal")) {
        my $net_conf = parse_network_configuration();
        my $mac = $net_conf->{fixed}->{mac};
        script_run "NIC=`grep $mac /sys/class/net/*/address |cut -d / -f 5`";
        assert_script_run("ip link set \$NIC down");
    }

    select_console("x11");
}
sub test_flags {
    return {fatal => 1};
}

1;
