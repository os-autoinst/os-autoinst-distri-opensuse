# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: NIS server-client test
#    https://progress.opensuse.org/issues/9900
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use lockapi 'mutex_create';
use mmapi 'wait_for_children';
use utils 'systemctl';
use y2x11test qw(setup_static_mm_network %setup_nis_nfs_x11);
use version_utils 'is_sle';
use x11utils 'turn_off_gnome_screensaver';
use y2logsstep 'yast2_console_exec';

sub setup_verification {
    script_run 'rpcinfo -u localhost ypserv';    # ypserv is running
    script_run 'rpcinfo -u localhost nfs';       # nfs is running
    script_run 'showmount -e localhost';         # show exprots
                                                 # check file created by client
    assert_script_run 'grep ' . "$setup_nis_nfs_x11{message} " . $setup_nis_nfs_x11{nfs_dir} . '/test';
    assert_script_run "cat /etc/exports | grep $setup_nis_nfs_x11{nfs_dir}";
    assert_script_run "cat /etc/exports | grep $setup_nis_nfs_x11{nfs_opts}";
}

sub nis_server_configuration {
    # NIS Server Setup
    assert_screen 'nis-server-setup-status', 150;
    send_key 'alt-m';                            # NIS master server
    save_screenshot;
    send_key $cmd{next};
    # Master Setup
    assert_screen 'nis-server-master-server-setup', 90;
    send_key 'tab';                              # jump to NIS domain name
    type_string $setup_nis_nfs_x11{nis_domain};
    assert_screen 'nis-server-master-server-setup-nis-domain';
    send_key 'alt-f';                            # open firewall port
    assert_screen 'nis-master-server-tab-opened-fw';
    wait_screen_change { send_key 'alt-a' };
    # unselect active slave NIS server exists checkbox
    assert_screen 'nis-master-server-setup-finished';
    send_key 'alt-o';                            # other global setting button
                                                 # NIS Master Server Details Setup
    assert_screen 'nis-server-master-server-detail-setup';
    send_key 'alt-o';                            # OK
    send_key $cmd{next};
    # NIS Server Maps Setup
    assert_screen 'nis-server-server-maps-setup';
    send_key 'tab';                              # jump to map list
    my $c = 1;                                   # select all maps
    while ($c <= 11) {
        send_key 'spc';
        send_key 'down';
        $c++;
    }
    assert_screen 'nis-server-server-maps-setup-finished';
    send_key $cmd{next};
    # NIS Server Query Hosts
    assert_screen 'nis-server-query-hosts-setup';
    send_key 'alt-a';                            # add
    assert_screen 'nis-server-network-conf-popup';
    type_string $setup_nis_nfs_x11{net_mask};
    send_key 'tab';
    type_string $setup_nis_nfs_x11{net_address};
    assert_screen 'nis-server-edit-netmask-network';
    wait_screen_change { send_key 'alt-o' };     # OK
    assert_screen 'nis-server-query-hosts-setup-finished';
    send_key 'alt-f';                            # finish
}

sub nfs_server_configuration {
    # NFS Server Configuration
    assert_screen 'nfs-server-configuration';
    send_key 'alt-f';                            # open port in firewall
    assert_screen 'nfs-server-configuration-opened-fw';
    wait_screen_change { send_key 'alt-s' };     # start nfs server
    send_key 'alt-m';                            # NFSv4 domain name field
    type_string $setup_nis_nfs_x11{nfs_domain};
    assert_screen 'nfs-server-configuration-nfsv4-domain';
    send_key 'alt-n';                            # next / OK

    # Setup Directories to Export
    assert_screen 'nfs-server-export';
    send_key 'alt-d';
    assert_screen 'nfs-server-export-popup';
    type_string $setup_nis_nfs_x11{nfs_dir};
    assert_screen 'nfs-server-export-popup-nfs-test-dir';
    send_key 'alt-o';                            # OK
    assert_screen 'nfs-server-directory-does-not-exist';
    send_key 'alt-y';                            # yes, create it
    assert_screen 'nfs-server-directory-mount-opts';
    send_key 'alt-p';                            # go to options field
    assert_screen 'nfs-server-directory-mount-opts-selected';
    send_key 'left';                             # unselect options and leave cursor at beginning
    wait_still_screen 4, 4;                      # blinking cursor
    send_key 'delete' for (0 .. 2);
    type_string $setup_nis_nfs_x11{nfs_opts};
    assert_screen 'nfs-server-directory-check-opts';
    save_screenshot;
    send_key 'alt-o';                            # OK
    assert_screen 'nfs-server-export';
    send_key 'alt-f';                            # finish
}

sub run {
    my ($self) = @_;
    x11_start_program('xterm -geometry 155x45+5+5', target_match => 'xterm');
    turn_off_gnome_screensaver if check_var('DESKTOP', 'gnome');
    become_root;
    setup_static_mm_network($setup_nis_nfs_x11{server_address});
    assert_script_run 'zypper -n in yast2-nis-server yast2-nfs-server';
    # Workarounds:
    # Yast2 does not open ports for SuseFirewall2 (bsc#999873)
    # Missing firewalld service files for NFS/NIS -> lack of support for RPC (bsc#1083486)
    if ($self->firewall eq 'firewalld') {
        record_soft_failure('bsc#1083486');
        my $firewalld_ypserv_service = get_test_data('x11/workaround_ypserv.xml');
        type_string("echo \"$firewalld_ypserv_service\" > /usr/lib/firewalld/services/ypserv.xml\n");
        my $firewalld_nfs_service = get_test_data('x11/workaround_nfs-kernel-server.xml');
        type_string("echo \"$firewalld_nfs_service\" > /usr/lib/firewalld/services/nfs-kernel-server.xml\n");
        assert_script_run('firewall-cmd --reload', fail_message => "Firewalld reload failed!");
    }
    if (is_sle) {
        systemctl 'stop ' . $self->firewall;
        record_soft_failure('bsc#999873');
    }
    my $module_name = y2logsstep::yast2_console_exec(yast2_module => 'nis_server');
    nis_server_configuration();
    wait_serial("$module_name-0", 360) || die "'yast2 nis server' didn't finish";
    assert_screen 'yast2_closed_xterm_visible';
    # NIS Server is configured and running, configuration continues on client side
    mutex_create('nis_ready');
    $module_name = y2logsstep::yast2_console_exec(yast2_module => 'nfs_server');
    nfs_server_configuration();
    wait_serial("$module_name-0", 360) || die "'yast2 nfs server' didn't finish";
    assert_screen 'yast2_closed_xterm_visible', 200;
    # NFS Server is configured and running, configuration continues on client side
    mutex_create('nfs_ready');
    wait_for_children;
    # Read content of a file created by the client
    setup_verification();
    type_string "killall xterm\n";    # game over -> xterm
}

sub test_flags {
    return {fatal => 1};
}

1;
