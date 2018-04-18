# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
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
use testapi;
use mm_network;
use lockapi;
use mmapi;
use utils qw(systemctl turn_off_gnome_screensaver);

sub run {
    my ($self) = @_;
    x11_start_program('xterm -geometry 155x45+5+5', target_match => 'xterm');
    become_root;
    turn_off_gnome_screensaver if check_var('DESKTOP', 'gnome');
    configure_default_gateway;
    configure_static_ip('10.0.2.1/24');
    configure_static_dns(get_host_resolv_conf());
    # added nfs for sle15
    assert_script_run 'zypper -n in yast2-nis-server yast2-nfs-server';
    if ($self->firewall eq 'firewalld') {
        my $firewalld_ypserv_service = get_test_data('x11/workaround_ypserv.xml');
        my $firewalld_nfs_service    = get_test_data('x11/workaround_nfs-kernel-server.xml');

        record_soft_failure('bsc#1083486');
        assert_script_run("echo \"$firewalld_ypserv_service\" > /usr/lib/firewalld/services/ypserv.xml");
        assert_script_run("echo \"$firewalld_nfs_service\" > /usr/lib/firewalld/services/nfs-kernel-server.xml");
        assert_script_run('firewall-cmd --reload');
    }

    type_string "yast2 nis_server\n";
    assert_screen 'nis-server-setup-status';
    send_key 'alt-m';    # NIS master server
    wait_still_screen 4;
    send_key $cmd{next};
    assert_screen 'nis-server-master-server-setup', 90;
    send_key 'tab';      # jump to NIS domain name
    type_string 'nis.openqa.suse.de';
    wait_screen_change { send_key 'alt-a' };    # unselect active slave NIS server exists checkbox
    send_key 'alt-f';                           # open firewall port
    wait_still_screen 4;
    save_screenshot;
    send_key 'alt-o';                           # other global setting button
    assert_screen 'nis-server-master-server-detail-setup';
    send_key 'alt-o';                           # OK
    send_key $cmd{next};
    assert_screen 'nis-server-server-maps-setup';
    send_key 'tab';                             # jump to map list
    my $c = 1;                                  # select all maps
    while ($c <= 11) {
        send_key 'spc';
        send_key 'down';
        $c++;
    }
    wait_still_screen 4;
    save_screenshot;
    send_key $cmd{next};
    send_key 'alt-a';                           # add
    wait_still_screen 4, 4;                     # blinking cursor
    type_string '255.255.255.0';
    send_key 'tab';
    type_string '10.0.2.0';
    send_key 'alt-o';                           # OK
    save_screenshot;
    send_key 'alt-f';                           # finish
    assert_screen 'yast2_closed_xterm_visible';
    mutex_create('nis_ready');                  # setup is done client can connect
    type_string "yast2 nfs_server\n";
    assert_screen 'nfs-server-configuration';
    send_key 'alt-f';                           # open port in firewall
    send_key 'alt-m';                           # NFSv4 domain name field
    type_string 'nfs.openqa.suse.de';
    wait_still_screen 4, 4;                     # blinking cursor
    send_key 'alt-s';                           # start nfs server
    wait_still_screen 4, 4;                     # blinking cursor
    send_key 'alt-n';                           # next / OK
    assert_screen 'nfs-server-export';
    send_key 'alt-d';
    wait_still_screen 4, 4;                     # blinking cursor
    type_string '/home/nis_user';
    send_key 'alt-o';                           # OK
    assert_screen 'nfs-server-directory-does-not-exist';
    send_key 'alt-y';                           # yes, create it
    wait_still_screen 4, 4;                     # blinking cursor
    send_key 'alt-p';                           # go to options field
    wait_still_screen 4, 4;                     # blinking cursor
    send_key 'left';                            # unselect options and leave cursor at beginning
    wait_still_screen 4, 4;                     # blinking cursor
    send_key 'delete';
    send_key 'delete';
    send_key 'delete';
    type_string 'rw,no_';                       # rw,no_root_squash
    wait_still_screen 4, 4;                     # blinking cursor
    save_screenshot;
    send_key 'alt-o';                           # OK
    assert_screen 'nfs-server-export';
    send_key 'alt-f';                           # finish
    assert_screen 'yast2_closed_xterm_visible';
    systemctl 'stop ' . $self->firewall;                              # bsc#999873
    script_run 'rpcinfo -u localhost ypserv';                         # ypserv is running
    script_run 'rpcinfo -u localhost nfs';                            # nfs is running
    script_run 'showmount -e localhost';                              # show exprots
    mutex_create('nfs_ready');                                        # setup is done client can connect
    wait_for_children;
    assert_script_run 'grep "nfs is working" /home/nis_user/test';    # check file created by client
    type_string "killall xterm\n";                                    # game over -> xterm
}

sub test_flags {
    return {fatal => 1};
}

1;
