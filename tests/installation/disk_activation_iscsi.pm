# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: initial installation: iSCSI client for the supportserver
#          supportserver to provide one iSCSI target which will
#          provide a multipathed second disk to the client.
# Maintainer: Klaus Wagner <kgw@suse.com>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    my $self = shift;
    my $iscsi_iqn;
    my $iscsi_server_ip;

    # Defaults: the values from the supportserver and client
    $iscsi_iqn       = get_var('ISCSI_IQN',       "iqn.2016-02.de.openqa");
    $iscsi_server_ip = get_var('ISCSI_SERVER_IP', "10.0.2.1");

    die "WITHISCSI not set" unless get_var('WITHISCSI');
    # Assumption: we are within an initial installation. Due to
    # kernel parameter "withiscsi=1" the YaST Disk Activation screen
    # is expected to come up.
    assert_screen 'disk-activation-iscsi', 180;
    send_key "alt-i";    # "Configure iSCSI Disks"
                         # screen "iSCSI Initiator Overwiew", Tab "Service"
    assert_screen 'iscsi-initiator-service-fs', 180;
    send_key "alt-i";    # go to initiator name field
    wait_still_screen(2, 10);
    type_string "$iscsi_iqn";
    wait_still_screen(2, 10);
    send_key "alt-n";    # "Connected Targets" tab, empty list
    assert_screen 'iscsi-initiator-connected-targets-none-fs';
    send_key $cmd{add};    # go to "iSCSI Initiator Discovery" screen
    assert_screen 'iscsi-discovery-fs';
    send_key "alt-i";      # go to IP address field
    wait_still_screen(2, 10);
    type_string "$iscsi_server_ip";
    send_key "alt-n";      # iSCSI Initiator Discovery: discovered targets list, first one is selected
    send_key "alt-o";      # press Connect button
    wait_still_screen(2, 10);
    assert_screen 'iscsi-initiator-startup-and-authentication';
    send_key "alt-s";       # startup mode. Selection list: *manual onboot automatic
    send_key "down";        # Wanted: onboot
    send_key $cmd{next};    # Now connect
    assert_screen 'iscsi-client-target-connected-fs';
    send_key $cmd{next};
    assert_screen 'iscsi-initiator-service-fs';
    send_key $cmd{ok};
    assert_screen 'disk-activation-iscsi';
    send_key $cmd{next};
}

sub test_flags {
    return {fatal => 1};
}

1;
