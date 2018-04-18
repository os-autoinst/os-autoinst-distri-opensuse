# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: NIS server-client test
# Maintainer: Jozef Pupava <jpupava@suse.com>
# Tags: https://progress.opensuse.org/issues/9900

use base "x11test";
use strict;
use testapi;
use mm_network;
use lockapi;
use utils qw(systemctl turn_off_gnome_screensaver);
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    x11_start_program('xterm -geometry 155x45+5+5', target_match => 'xterm');
    become_root;
    turn_off_gnome_screensaver if check_var('DESKTOP', 'gnome');
    configure_default_gateway;
    configure_static_ip('10.0.2.3/24');
    configure_static_dns(get_host_resolv_conf());
    if ($self->firewall eq 'firewalld') {
        my $firewalld_ypbind_service = get_test_data('x11/workaround_ypbind.xml');

        record_soft_failure('bsc#1089851');
        assert_script_run("echo \"$firewalld_ypbind_service\" > /usr/lib/firewalld/services/ypbind.xml");
        assert_script_run('firewall-cmd --reload');
    }
    systemctl 'stop ' . $self->firewall;    # bsc#999873
    assert_script_run 'zypper -n in yast2-nis-server';
    mutex_lock('nis_ready');                # wait for NIS server setup
    type_string "yast2 nis\n";
    if (is_sle('>=15')) {
        assert_screen 'nis-client-install-missing-package';
        send_key 'alt-i';                   # install missing ypbind rpm
    }
    assert_screen 'nis-client-configuration';
    send_key 'alt-u';                       # use NIS radio button
    wait_still_screen 4;
    send_key 'alt-i';                       # NIS domain
    type_string 'nis.openqa.suse.de';
    send_key 'alt-l';                       # open firewall port
    wait_still_screen 4;
    send_key 'alt-d';                       # find NIS server
    assert_screen 'nis-client-server-in-domain', 120;
    send_key 'spc';                         # select found NIS server
    send_key 'alt-o';                       # OK
    send_key 'alt-m';                       # start automounter
    mutex_lock('nfs_ready');                # wait for NFS server setup
    send_key 'alt-s';                       # nfs configuation button
    assert_screen 'nis-client-nfs-client-configuration';
    send_key 'alt-s';                       # nfs settings tab
    send_key 'alt-f';                       # open firewall port
    send_key 'alt-v';                       # nfsv4 domain name field
    type_string 'nfs.openqa.suse.de';
    wait_still_screen 4, 4;                 # blinking cursor
    save_screenshot;
    send_key 'alt-n';                       # nfs shares tab
    send_key 'alt-a';                       # add
    wait_still_screen 4;
    send_key 'alt-v';                       # NFSV4 share checkbox
    send_key 'alt-s';                       # choose NFS server button
    assert_screen 'nis-client-nfs-server';
    send_key 'alt-o';                       # OK
    send_key 'alt-r';                       # remote directory text field
    type_string '/home/nis_user';
    send_key 'alt-m';                       # mount point text field
    type_string '/home/nis_user';
    send_key 'alt-o';                       # OK
    assert_screen 'nis-client-nfs-client-configuration';
    send_key 'alt-o';                       # OK
    assert_screen 'nis-client-configuration';
    send_key 'alt-f';                       # finish
    assert_screen 'yast2_closed_xterm_visible', 90;
    script_run 'mount|grep nfs';            # print nfs mounts
    if (is_sle('>=15')) {
        record_soft_failure('bsc#1090886');
        script_run('mount -vt nfs /home/nis_user');
    }
    script_run 'mount|grep nfs';                                 # verify mounted nfs
    script_run 'echo "nfs is working" > /home/nis_user/test';    # create file with text, will be checked by server
    type_string "killall xterm\n";                               # game over -> xterm
}

1;
