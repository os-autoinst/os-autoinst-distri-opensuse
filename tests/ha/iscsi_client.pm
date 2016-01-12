# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "hacluster";
use testapi;

sub run() {
    my $self = shift;
    type_string "yast2 iscsi-client\n";
    assert_screen "yast2-iscsi-client";
    send_key 'alt-b';    #start iscsi daemon on Boot
    send_key 'alt-i';    #Initiator name
    for (1 .. 40) { send_key "backspace"; }
    type_string "iqn.1996-04.de.suse:01:" . get_var("HOSTNAME") . "." . get_var("CLUSTERNAME");
    save_screenshot;
    send_key 'alt-v';    #discoVered targets
    assert_screen "yast2-iscsi-client-discovered-targets";
    send_key 'alt-d';    #Discovery
    assert_screen "yast2-iscsi-client-discovery";
    send_key 'alt-i';    #Ip address
    type_string "srv1";
    send_key 'alt-n';    #Next
    assert_screen "yast2-iscsi-client-target-list";
    #select target with internal IP first?
    send_key 'alt-e';    #connEct
    assert_screen "yast2-iscsi-client-target-startup";
    send_key 'alt-s';    #Startup
    send_key 'down';
    send_key 'down';     #select 'automatic'
    assert_screen "yast2-iscsi-client-target-startup-automatic-selected";
    send_key 'ret';
    send_key 'alt-n';    #Next
    assert_screen "yast2-iscsi-client-target-connected";
    send_key 'alt-o';    #Ok
    wait_still_screen;
    $self->clear_and_verify_console;
    type_string "echo \"iscsi_luns=`ls -1 /dev/disk/by-path/ip-*-lun-* | wc -l`\" > /dev/$serialdev\n";
    die "iscsi_client failed" unless wait_serial "iscsi_luns=3";
}

sub test_flags {
    return {fatal => 1};
}

1;
