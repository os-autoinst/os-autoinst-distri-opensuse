# SUSE's openQA tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: rpcbind nfs-client yast2-nis-server yast2-nfs-server
# Summary: NIS server-client test
#    https://progress.opensuse.org/issues/9900
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use lockapi;
use mmapi;
use utils;
use mm_network 'setup_static_mm_network';
use y2_module_guitest '%setup_nis_nfs_x11';
use x11utils 'turn_off_gnome_screensaver';
use y2_module_consoletest;
use scheduler 'get_test_suite_data';

sub setup_verification {
    script_run 'rpcinfo -u localhost ypserv';    # ypserv is running
    script_run 'rpcinfo -u localhost nfs';    # nfs is running
    script_run 'showmount -e localhost';    # show exprots
                                            # check file created by client
    assert_script_run 'grep ' . "$setup_nis_nfs_x11{message} " . $setup_nis_nfs_x11{nfs_dir} . '/test';
    assert_script_run "cat /etc/exports | grep $setup_nis_nfs_x11{nfs_dir}";
    assert_script_run "cat /etc/exports | grep $setup_nis_nfs_x11{nfs_opts}";
}

sub nis_server_configuration {
    my $test_data = get_test_suite_data();
    # NIS Server Setup
    assert_screen 'nis-server-setup-status', 150;
    send_key 'alt-m';    # NIS master server
    save_screenshot;
    send_key $cmd{next};
    # Master Setup
    assert_screen 'nis-server-master-server-setup', 90;
    send_key 'tab';    # jump to NIS domain name
    type_string $setup_nis_nfs_x11{nis_domain};
    assert_screen 'nis-server-master-server-setup-nis-domain';
    # Focus on the dialog is lost sporadically, clicking somewhere solves it
    assert_and_click 'nis-server-master-server-setup';
    # unselect active slave NIS server exists checkbox
    wait_screen_change { send_key 'alt-a' };
    assert_screen 'nis-master-server-setup-finished';
    send_key 'alt-o';    # other global setting button
                         # NIS Master Server Details Setup
    assert_screen 'nis-server-master-server-detail-setup';
    send_key 'alt-o';    # OK
    send_key $cmd{next};
    # NIS Server Maps Setup
    assert_screen 'nis-server-server-maps-setup';
    send_key 'tab';    # jump to map list
    my $c = 1;    # select all maps
    while ($c <= $test_data->{maps}) {
        send_key 'spc';
        send_key 'down';
        $c++;
    }
    assert_screen 'nis-server-server-maps-setup-finished';
    send_key $cmd{next};
    # NIS Server Query Hosts
    assert_screen 'nis-server-query-hosts-setup';
    send_key 'alt-a';    # add
    assert_screen 'nis-server-network-conf-popup';
    type_string $setup_nis_nfs_x11{net_mask};
    send_key 'tab';
    type_string $setup_nis_nfs_x11{net_address};
    assert_screen 'nis-server-edit-netmask-network';
    wait_screen_change { send_key 'alt-o' };    # OK
    assert_screen 'nis-server-query-hosts-setup-finished';
    send_key 'alt-f';    # finish
}

sub nfs_server_configuration {
    # NFS Server Configuration
    assert_screen 'nfs-server-configuration';
    send_key 'alt-s';    # start nfs server
    send_key 'alt-m';    # NFSv4 domain name field
    type_string $setup_nis_nfs_x11{nfs_domain};
    assert_screen 'nfs-server-configuration-nfsv4-domain';
    send_key 'alt-n';    # next / OK

    # Setup Directories to Export
    assert_screen 'nfs-server-export';
    send_key 'alt-d';
    assert_screen 'nfs-server-export-popup';
    type_string $setup_nis_nfs_x11{nfs_dir};
    assert_screen 'nfs-server-export-popup-nfs-test-dir';
    send_key 'alt-o';    # OK
    assert_screen 'nfs-server-directory-does-not-exist';
    send_key 'alt-y';    # yes, create it
    assert_screen 'nfs-server-directory-mount-opts';
    send_key 'alt-p';    # go to options field
    assert_screen 'nfs-server-directory-mount-opts-selected';
    send_key 'left';    # unselect options and leave cursor at beginning
    wait_still_screen 4, 4;    # blinking cursor
    send_key 'delete' for (0 .. 2);
    type_string $setup_nis_nfs_x11{nfs_opts};
    assert_screen 'nfs-server-directory-check-opts';
    save_screenshot;
    send_key 'alt-o';    # OK
    assert_screen 'nfs-server-export';
    send_key 'alt-f';    # finish
}

sub run {
    my ($self) = @_;
    x11_start_program('xterm -geometry 155x45+5+5', target_match => 'xterm');
    turn_off_gnome_screensaver if check_var('DESKTOP', 'gnome');
    become_root;
    setup_static_mm_network($setup_nis_nfs_x11{server_address});
    zypper_call 'in yast2-nis-server yast2-nfs-server';

    # we have to stop the firewall, see bsc#999873 and bsc#1083487#c36
    systemctl 'stop ' . $self->firewall;

    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'nis_server');
    nis_server_configuration();
    wait_serial("$module_name-0", 360) || die "'yast2 nis server' didn't finish";
    assert_screen 'yast2_closed_xterm_visible';
    $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'nfs_server');
    nfs_server_configuration();
    wait_serial("$module_name-0", 360) || die "'yast2 nfs server' didn't finish";
    assert_screen 'yast2_closed_xterm_visible', 200;
    # In order for the hostname to get the set value via yast2 nis_server, a restart is needed. Otherwise "make"
    # command won't work as in Makefile, there is a variable that gets it's value from "domainname" command
    systemctl 'restart network';
    # NIS and NFS Server is configured and running, configuration continues on client side
    mutex_create('nis_nfs_server_ready');
    my $children = get_children();
    my $child_id = (keys %$children)[0];
    mutex_wait('nis_nfs_client_ready', $child_id);
    # Read content of a file created by the client
    setup_verification();
    enter_cmd "killall xterm";    # game over -> xterm
}

sub test_flags {
    return {fatal => 1};
}

1;
