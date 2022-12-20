# SUSE's openQA tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-nis-server yast2-nfs-client
# Summary: NIS server-client test
# Maintainer: Jozef Pupava <jpupava@suse.com>
# Tags: https://progress.opensuse.org/issues/9900

use base "x11test";
use strict;
use warnings;
use testapi;
use lockapi;
use utils;
use version_utils 'is_opensuse';
use mm_network 'setup_static_mm_network';
use y2_module_guitest '%setup_nis_nfs_x11';
use x11utils 'turn_off_gnome_screensaver';
use y2_module_consoletest;

sub setup_nis_client {
    my $server_ip = shift;
    assert_screen 'nis-client-configuration', 120;
    send_key 'alt-u';    # use NIS radio button
    wait_still_screen 4;
    send_key 'alt-i';    # NIS domain
    type_string $setup_nis_nfs_x11{nis_domain};
    send_key 'alt-m';    # start automounter
    wait_still_screen 4;
    send_key 'alt-d';    # find NIS server
    assert_screen [qw(nis-client-server-in-domain nis_servers_in_domain_empty)], 120;
    if (match_has_tag 'nis_servers_in_domain_empty') {
        record_soft_failure "bsc#1167589 - yast2 nis and nfs clients do not find server on the same lan";
        # Validate then enter address manually
        send_key 'alt-o';
        wait_screen_change { send_key 'alt-a' };
        type_string $server_ip;
        assert_screen 'nis_server_address_filled';
    } elsif (match_has_tag 'nis-client-server-in-domain') {
        send_key 'spc';    # select found NIS server
        assert_screen 'nis-client-server-in-domain-selected';
        send_key 'alt-o';    # OK
    }
    save_screenshot;
}

sub nfs_settings_tab {
    assert_screen 'nis-client-enter-nfs-configuration';
    send_key 'alt-s';    # nfs configuration button
    assert_screen 'nis-client-nfs-client-configuration';
    send_key 'alt-s';    # nfs settings tab
    assert_screen 'nis-client-nfs-settings-tab';
    send_key 'alt-v';    # nfsv4 domain name field
    type_string $setup_nis_nfs_x11{nfs_domain};
    wait_still_screen 4, 4;    # blinking cursor
    save_screenshot;
}

sub nfs_shares_tab {
    my $server_ip = shift;
    send_key 'alt-n';    # nfs shares tab
    assert_screen 'nis-client-nfs-client-shares-conf';
    send_key 'alt-a';    # add
    assert_screen 'nis-client-add-nfs-share';
    # On 15-SP2 "Any (Highest Available)" is selected by default, just keep it.
    assert_screen 'nis-client-default-nfs-version';
    send_key 'alt-s';    # choose NFS server button
    assert_screen [qw(nis-client-nfs-server no_nfs_server_found)];
    if (match_has_tag 'no_nfs_server_found') {
        record_soft_failure "bsc#1167589 - yast2 nis and nfs clients do not find server on the same lan";
        # Validate then enter address manually
        send_key 'alt-o';    # OK
        wait_screen_change { send_key "alt-n" };
        type_string $server_ip;
    } elsif (match_has_tag 'nis-client-nfs-server') {
        send_key 'alt-o';    # OK
    }
    assert_screen 'nis-client-add-nfs-share-filled';
    send_key 'alt-r';    # remote directory text field
    type_string $setup_nis_nfs_x11{nfs_dir};
    assert_screen 'nis-client-add-nfs-share-remotedir';
    send_key 'alt-m';    # mount point text field
    type_string $setup_nis_nfs_x11{nfs_dir};
    assert_screen 'nis-client-add-nfs-share-mountpoint';
    send_key 'alt-o';    # OK
    assert_screen 'nis-client-nfs-client-configuration';
    send_key 'alt-o';    # OK
    assert_screen 'nis-client-configuration', 120;
    send_key 'alt-f';    # finish
    if (is_opensuse) {
        assert_screen 'disable_auto_login_popup';
        send_key "alt-y";
    }
}

sub setup_verification {
    my $server_ip = shift;
    assert_screen 'yast2_closed_xterm_visible', 90;
    script_run 'mount|grep nfs';    # print nfs mounts
    script_run "cat /proc/mounts | grep -i $server_ip:";
    # create file with text, will be checked by server
    script_run 'echo ' . $setup_nis_nfs_x11{message} . " > " . $setup_nis_nfs_x11{nfs_dir} . '/test';
}

sub run {
    my ($self) = @_;
    my ($server_ip, $mask) = split('/', $setup_nis_nfs_x11{server_address});
    x11_start_program('xterm -geometry 155x45+5+5', target_match => 'xterm');
    turn_off_gnome_screensaver if check_var('DESKTOP', 'gnome');
    become_root;
    setup_static_mm_network($setup_nis_nfs_x11{client_address});
    zypper_call 'in yast2-nis-server yast2-nfs-client';

    # we have to stop the firewall, see bsc#999873 and bsc#1083487#c36
    systemctl 'stop ' . $self->firewall;

    mutex_wait('nis_nfs_server_ready');    # wait for server setup
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'nis');
    setup_nis_client($server_ip);
    nfs_settings_tab();
    nfs_shares_tab($server_ip);
    wait_serial("$module_name-0", 360) || die "'yast2 nis client' didn't finish";
    setup_verification();
    mutex_create('nis_nfs_client_ready');
    enter_cmd "killall xterm";    # game over -> xterm
}

1;
