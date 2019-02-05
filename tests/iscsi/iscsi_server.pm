# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test suite for iSCSI server and client
#    Multimachine testsuites, server test creates iscsi target and client test uses it
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "x11test";
use strict;
use testapi;
use mm_network;
use lockapi;
use version_utils qw(is_sle is_leap);
use mmapi;
use utils 'zypper_call';
use yast2_widget_utils 'change_service_configuration';
use x11utils 'turn_off_gnome_screensaver';

sub run {
    my $self = shift;

    x11_start_program('xterm -geometry 160x45+5+5', target_match => 'xterm');
    turn_off_gnome_screensaver;
    become_root;
    configure_default_gateway;
    configure_static_ip('10.0.2.1/24');
    configure_static_dns(get_host_resolv_conf());
    zypper_call 'in yast2-iscsi-lio-server';
    assert_script_run 'dd if=/dev/zero of=/root/iscsi-disk seek=1M bs=8192 count=1';    # create iscsi LUN
    type_string "yast2 iscsi-lio-server; echo yast2-iscsi-server-\$? > /dev/$serialdev\n";
    assert_screen 'iscsi-lio-server';
    unless (is_sle('<15') || is_leap('<15.1')) {
        change_service_configuration(
            after_writing => {start         => 'alt-w'},
            after_reboot  => {start_on_boot => 'alt-a'}
        );
    }
    send_key 'alt-o';                                                                   # open port in firewall
    wait_still_screen(2, 10);
    assert_screen 'iscsi-target-overview-service-tab';
    send_key 'alt-g';                                                                   # go to global tab
    assert_screen 'iscsi-target-overview-global-tab';
    send_key 'alt-t';                                                                   # go to target tab
    wait_still_screen(2, 10);
    send_key 'alt-a';                                                                   # add target
    wait_still_screen(2, 10);
    send_key 'alt-t';                                                                   # select target field
    wait_still_screen(2, 10);
    send_key 'ctrl-a';                                                                  # select all text inside target field
    wait_still_screen(2, 10);
    send_key 'delete';                                                                  # text it is automatically selected after tab, delete
    type_string 'iqn.2016-02.de.openqa';
    wait_still_screen(2, 10);
    send_key 'tab';                                                                     # tab to identifier field
    wait_still_screen(2, 10);
    send_key 'delete';
    wait_still_screen(2, 10);
    type_string '132';
    wait_still_screen(2, 10);
    if (is_sle('>=15')) {
        send_key 'alt-l';                                                               # un-check bind all IPs
    }
    else {
        send_key 'alt-u';                                                               # un-check use authentication
    }
    wait_still_screen(2, 10);
    send_key 'alt-a';                                                                   # add LUN
    my $lunpath_key = is_sle('>=15') ? 'alt-l' : 'alt-p';
    send_key_until_needlematch 'iscsi-target-LUN-path-selected', $lunpath_key, 5, 5;    # send $lunpath_key until LUN path is selected
    type_string '/root/iscsi-disk';
    assert_screen 'iscsi-target-LUN';
    send_key 'alt-o';                                                                   # OK
    assert_screen 'iscsi-target-overview';
    send_key 'alt-n';                                                                   # next
    wait_still_screen(2, 10);
    if (is_sle('<15')) {
        send_key 'alt-a';                                                               # add client
        send_key_until_needlematch 'iscsi-client-name-selected', 'tab';                 # there is no field shortcut, so tab till client name field is selected
        type_string 'iqn.2016-02.de.openqa';
        assert_screen 'iscsi-target-client-name';
        send_key 'alt-o';                                                               # OK
        assert_screen 'iscsi-target-client-setup';
        send_key 'alt-n';                                                               # next
    }
    assert_screen 'iscsi-target-overview-target-tab';
    send_key 'alt-f';                                                                   # finish
    wait_serial("yast2-iscsi-server-0", 180) || die "'yast2 iscsi-lio ' didn't finish or exited with non-zero code";
    mutex_create('iscsi_ready');                                                        # setup is done client can connect
    type_string "killall xterm\n";
    wait_for_children;                                                                  # run till client is done
    $self->result('ok');
}

sub test_flags {
    return {fatal => 1};
}

1;
