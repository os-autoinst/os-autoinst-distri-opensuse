# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Test suite for iSCSI server and client
#    Multimachine testsuites, server test creates iscsi target and client test uses it
# G-Maintainer: Jozef Pupava <jpupava@suse.com>

use base "x11test";
use strict;
use testapi;
use mm_network;
use lockapi;
use mmapi;

sub run() {
    my $self = shift;

    x11_start_program("xterm -geometry 160x45+5+5");
    type_string "gsettings set org.gnome.desktop.session idle-delay 0\n";    # disable blank screen
    become_root;
    configure_default_gateway;
    configure_static_ip('10.0.2.1/24');
    configure_static_dns(get_host_resolv_conf());
    assert_script_run 'zypper -n in yast2-iscsi-lio-server';
    assert_script_run 'dd if=/dev/zero of=/root/iscsi-disk seek=1M bs=8192 count=1';    # create iscsi LUN
    type_string "yast2 iscsi-lio-server\n";
    assert_screen 'iscsi-lio-server';
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
    send_key 'ctrl-a';    # select all text inside target field
    wait_still_screen(2, 10);
    send_key 'delete';    # text it is automatically selected after tab, delete
    type_string 'iqn.openqa.de';
    wait_still_screen(2, 10);
    send_key 'tab';       # tab to identifier field
    wait_still_screen(2, 10);
    send_key 'delete';
    wait_still_screen(2, 10);
    type_string '132';
    wait_still_screen(2, 10);
    send_key 'alt-u';     # un-check use authentication
    wait_still_screen(2, 10);
    send_key 'alt-a';     # add LUN
    send_key_until_needlematch 'iscsi-target-LUN-path-selected', 'alt-p', 5, 5;  # send alt-p until LUN path is selected
    type_string '/root/iscsi-disk';
    assert_screen 'iscsi-target-LUN';
    send_key 'alt-o';                                                            # OK
    assert_screen 'iscsi-target-overview';
    send_key 'alt-n';                                                            # next
    wait_still_screen(2, 10);
    send_key 'alt-a';                                                            # add client
    send_key_until_needlematch 'iscsi-client-name-selected',
      'tab';    # there is no field shortcut, so tab till client name field is selected
    type_string 'iqn.2016-02.de.openqa';
    assert_screen 'iscsi-target-client-name';
    send_key 'alt-o';    # OK
    assert_screen 'iscsi-target-client-setup';
    send_key 'alt-n';    # next
    assert_screen 'iscsi-target-overview-target-tab';
    send_key 'alt-f';    # finish
    wait_still_screen(2, 10);
    mutex_create('iscsi_ready');    # setup is done client can connect
    type_string "killall xterm\n";
    wait_for_children;              # run till client is done
    $self->result('ok');
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
