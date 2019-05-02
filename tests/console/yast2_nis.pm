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
use warnings;
use base "console_yasttest";
use testapi;
use utils 'zypper_call';

sub run() {
    my ($self) = @_;
    select_console 'root-console';
    zypper_call 'in yast2-nis-client';    # make sure yast client module installed

    # Configure firewalld ypbind service (bsc#1083487)
    if ($self->firewall eq 'firewalld' && script_run 'firewall-offline-cmd --get-services | grep ypbind') {
        record_soft_failure('bsc#1083487');
        assert_script_run 'firewall-cmd --permanent --new-service=ypbind';
        assert_script_run 'firewall-cmd --permanent --service=ypbind --add-port=717/tcp';
        assert_script_run 'firewall-cmd --permanent --service=ypbind --add-port=714/udp';
        assert_script_run 'firewall-cmd --reload';
    }
    y2logsstep::yast2_console_exec(yast2_module => 'nis');
    assert_screen([qw(nis-client yast2_package_install)], 60);
    if (match_has_tag 'yast2_package_install') {
        send_key 'alt-i';
    }
    wait_still_screen;    # install package takes a long time
    send_key 'alt-u';
    wait_screen_change { send_key 'alt-t' };
    assert_screen([qw(open_port_in_firewall yast2_cannot-open-interface)]);
    if (match_has_tag 'yast2_cannot-open-interface') {
        record_soft_failure 'bsc#1069458';
        send_key 'alt-y';
    }
    send_key 'alt-m';
    assert_screen 'nis-client-automounter-enabled';    # this checks if nis and automounter got really enabled
    send_key 'alt-i';                                  # enter Nis domain for enter string suse.de
    send_key_until_needlematch 'nis-domain-empty-field', 'backspace';    # clear NIS Domain field if it is prefilled
    type_string "suse.de";
    send_key 'alt-a';
    type_string "10.162.0.1";
    wait_screen_change { send_key 'alt-p' };                             # check Netconfif NIS Policy
    send_key 'up';
    wait_screen_change { send_key 'ret' };
    assert_screen 'only-manual-changes';                                 # check the needle
    send_key 'alt-p';                                                    # enter Netconfif NIS Policy again for custom policy
    wait_screen_change { send_key 'down' };
    send_key 'ret';
    wait_screen_change { send_key 'alt-x' };                             # check Expert...
    wait_screen_change { send_key 'alt-b' };
    assert_screen 'expert_settings';                                     # check the needle enable Broken server
    send_key 'alt-y';
    wait_screen_change { type_string "-c" };                             # only checks if the config file has syntax errors and exits
    wait_screen_change { send_key 'alt-o' };
    wait_screen_change { send_key 'alt-s' };                             # enter NFS configuration,sometimes fails, retry
    sleep(4);
    send_key 'alt-s' if check_screen('nis-client');                      # Cannot use send_key_until_needlematch, see poo#48647
    assert_screen 'nfs-client-configuration';
    send_key 'alt-a';                                                    # add nfs share
    assert_screen 'nfs-server-hostname';                                 # check that type string is sucessful
    send_key 'alt-n';                                                    # from here enter some configurations...
    type_string "nis.suse.de";
    send_key 'alt-r';
    type_string "/mounts";
    send_key 'alt-m';
    type_string "/mounts_local";
    send_key 'alt-o';
    assert_screen 'nfs_server_added';                                    # check Mount point
    wait_screen_change { send_key 'alt-t' };                             # go back to nfs configuration and delete configuration created before
    assert_screen 'nis_server_delete';                                   # confirm to delete configuration
    send_key 'alt-y';
    wait_still_screen 2;
    send_key 'alt-o';
    wait_still_screen 2;
    send_key 'alt-f';                                                    # close the dialog...
    assert_screen([qw(nis_server_not_found ypbind_error)]);
    if (match_has_tag 'ypbind_error') {
        record_soft_failure 'bsc#1073281';
        send_key 'alt-o';
    }
    else {
        send_key 'alt-o';                                                # close it now even when config is not valid
    }    # check error message for 'nis server not found'
}
1;

