# SUSE's openQA tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: smt yast2-smt
# Summary: Disconnected SMT internal
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "x11test";
use strict;
use warnings;
use testapi;
use lockapi;
use mmapi;
use mm_network;
use repo_tools;
use x11utils 'turn_off_gnome_screensaver';

sub run {
    my ($self) = @_;
    my $external_IP = '10.0.2.111';
    x11_start_program('xterm -geometry 150x35+5+5', target_match => 'xterm');
    turn_off_gnome_screensaver;
    become_root;

    # setting internal SMT configure
    smt_wizard();

    # setting internal SMT server
    enter_cmd("yast2 smt-server;echo yast2-smt-server-\$? > /dev/$serialdev");
    assert_screen("smt-server-1");
    send_key("alt-s");
    assert_screen("smt-server-jobs");
    send_key("alt-t");    # delete SCC Registration job
    assert_screen("smt-delete-entry");
    send_key("alt-y");
    send_key("alt-t");    # delete Synchronization of Updates job
    assert_screen("smt-delete-entry");
    send_key("alt-y");
    send_key("alt-o");
    assert_screen("smt-mariadb-password-required");
    type_password;
    send_key("alt-o");
    assert_screen 'smt-sync-failed', 100;
    send_key 'alt-o';
    wait_serial("yast2-smt-server-0", 400) || die 'smt server failed';

    # network up and mount mobile disk
    my $net_conf = parse_network_configuration();
    my $mac = $net_conf->{fixed}->{mac};
    script_run "NIC=`grep $mac /sys/class/net/*/address |cut -d / -f 5`";
    assert_script_run("ip link set \$NIC up");
    assert_script_run("mount -t nfs $external_IP\:\/mnt\/Mobile-disk \/mnt\/Mobile-disk");

    mutex_lock('disconnect_smt_1');
    mutex_unlock('disconnect_smt_1');

    # smt sync from mobile disk and create update DB
    assert_script_run("smt-sync --fromdir \/mnt\/Mobile-disk", 600);
    assert_script_run("smt-repos --enable-mirror SLES12-SP3-Installer-Updates sle-12-x86_64");
    assert_script_run("smt-sync --createdbreplacementfile \/mnt\/Mobile-disk\/updateDB", 600);

    # internal smt create a mutex to let external sync repos
    mutex_create("disconnect_smt_2");

    mutex_lock('disconnect_smt_3');
    mutex_unlock('disconnect_smt_3');

    # daily Internal SMT Server Operation
    assert_script_run("smt-sync --fromdir \/mnt\/Mobile-disk", 600);
    assert_script_run("smt-mirror --fromdir \/mnt\/Mobile-disk", 600);
    assert_script_run("smt-sync --createdbreplacementfile \/mnt\/Mobile-disk\/updateDB", 600);
    # check enabled repos
    assert_script_run("smt-repos  --only-enabled | grep SLES12-SP3-Installer-Updates");
    assert_script_run("umount \/mnt\/Mobile-disk");

    enter_cmd "killall xterm";
}

sub test_flags {
    return {fatal => 1};
}

1;
