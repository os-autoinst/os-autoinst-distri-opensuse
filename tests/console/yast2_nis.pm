# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: create and delete nis client configuration and functionality
# Maintainer: Zaoliang Luo <zluo@suse.de>

use strict;
use base "console_yasttest";
use testapi;

sub run() {

    select_console 'root-console';
    script_run "zypper -n in yast2-nis-client";    # make sure yast client module installed
    type_string "yast2 nis\n";
    assert_screen 'nis-client';
    wait_screen_change { send_key 'alt-u' };
    send_key 'alt-m';
    assert_screen 'nis-client-automounter-enabled';    # this checks if nis and automounter got really enabled
    send_key 'alt-i';                                  # enter Nis domain for enter string suse.de
    type_string "suse.de";
    send_key 'alt-a';
    type_string "10.162.0.1";
    send_key 'alt-t';                                  # open port in firewall
    assert_screen 'open_port_in_firewall';             # check the port is open
    wait_screen_change { send_key 'alt-p' };           # check Netconfif NIS Policy
    send_key 'up';
    wait_screen_change { send_key 'ret' };
    assert_screen 'only-manual-changes';               # check the needle
    send_key 'alt-p';                                  # enter Netconfif NIS Policy again for custom policy
    wait_screen_change { send_key 'down' };
    send_key 'ret';
    wait_screen_change { send_key 'alt-x' };           # check Expert...
    wait_screen_change { send_key 'alt-b' };
    assert_screen 'expert_settings';                   # check the needle enable Broken server
    send_key 'alt-y';
    wait_screen_change { type_string "-c" };           # only checks if the config file has syntax errors and exits
    send_key 'alt-o';
    assert_screen 'nis-client-configuration';
    send_key 'alt-s';                                  # enter NFS configuration...
    assert_screen 'nfs-client-configuration';          # add nfs settings
    send_key 'alt-a';
    assert_screen 'nfs-server-hostname';               # check that type string is sucessful
    send_key 'alt-n';                                  # from here enter some configurations...
    type_string "nis.suse.de";
    send_key 'alt-r';
    type_string "/mounts";
    send_key 'alt-m';
    type_string "/mounts_local";
    send_key 'alt-o';
    assert_screen 'nfs_server_added';                  # check Mount point
    wait_screen_change { send_key 'alt-t' };    # go back to nfs configuration and delete configuration created before
    assert_screen 'nis_server_delete';          # confirm to delete configuration
    send_key 'alt-y';
    wait_screen_change { send_key 'alt-o' };
    send_key 'alt-f';                           # close the dialog...
    assert_screen 'nis_server_not_found';       # check error message for 'nis server not found'
    send_key 'alt-o';                           # close it now even when config is not valid
}
1;

# vim: set sw=4 et:

