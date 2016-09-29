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

sub run() {
    my $self = shift;

    x11_start_program("xterm -geometry 160x45+5+5");
    type_string "gsettings set org.gnome.desktop.session idle-delay 0\n";    # disable blank scree
    become_root;
    configure_default_gateway;
    configure_static_ip('10.0.2.3/24');
    configure_static_dns(get_host_resolv_conf());
    type_string "yast2 iscsi-client\n";
    assert_screen 'iscsi-client', 60;
    mutex_lock('iscsi_ready');                                               # wait for server setup
    send_key "alt-i";                                                        # go to initiator name field
    wait_still_screen(2, 10);
    type_string "iqn.2016-02.de.openqa";
    wait_still_screen(2, 10);
    assert_screen 'iscsi-initiator-service';
    send_key "alt-v";                                                        # go to discovered targets tab
    wait_still_screen(2, 10);
    send_key "alt-d";                                                        # press discovery button
    wait_still_screen(2, 10);
    send_key "alt-i";                                                        # go to IP address field
    wait_still_screen(2, 10);
    type_string "10.0.2.1";
    assert_screen 'iscsi-initiator-discovered-IP-adress';
    send_key "alt-n";                                                        # next
    assert_and_click 'iscsi-initiator-connect-button';                       # press connect button
    assert_screen 'iscsi-initiator-connect-manual';
    send_key "alt-n";                                                        # go to connected targets tab
    assert_screen 'iscsi-initiator-discovered-targets';
    send_key "alt-n";                                                        # next
    assert_screen 'iscsi-initiator-connected-targets';
    send_key "alt-o";                                                        # OK
    wait_still_screen(2, 10);
    assert_script_run 'lsscsi';
    assert_script_run "echo -e \"n\\np\\n1\\n\\n\\nw\\n\" \| fdisk /dev/sda";    # create one partition
    assert_script_run 'mkfs.ext4 /dev/sda1';                                     # format partition to ext4
    assert_script_run 'mount /dev/sda1 /mnt';                                    # mount partition to /mnt
    assert_script_run 'echo "iscsi is working" > /mnt/iscsi';                    # write text to file on iscsi disk
    assert_script_run 'grep "iscsi is working" /mnt/iscsi';                      # grep expected text from file
    type_string "killall xterm\n";
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return {important => 1};
}

1;
# vim: set sw=4 et:
