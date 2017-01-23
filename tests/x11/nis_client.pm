# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
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

sub run() {
    x11_start_program("xterm -geometry 155x45+5+5");
    type_string "gsettings set org.gnome.desktop.session idle-delay 0\n";    # disable blank scree
    become_root;
    configure_default_gateway;
    configure_static_ip('10.0.2.3/24');
    configure_static_dns(get_host_resolv_conf());
    script_run 'SuSEfirewall2 stop';                                         # bsc#999873
    assert_script_run 'zypper -n in yast2-nis-server';
    mutex_lock('nis_ready');                                                 # wait for NIS server setup
    type_string "yast2 nis\n";
    assert_screen 'nis-client-configuration';
    send_key 'alt-u';                                                        # use NIS radio button
    wait_still_screen 4;
    send_key 'alt-i';                                                        # NIS domain
    type_string 'nis.openqa.suse.de';
    send_key 'alt-l';                                                        # open firewall port
    wait_still_screen 4;
    send_key 'alt-d';                                                        # find NIS server
    assert_screen 'nis-client-server-in-domain', 120;
    send_key 'spc';                                                          # select found NIS server
    send_key 'alt-o';                                                        # OK
    send_key 'alt-m';                                                        # start automounter
    mutex_lock('nfs_ready');                                                 # wait for NFS server setup
    send_key 'alt-s';                                                        # nfs configuation button
    assert_screen 'nis-client-nfs-client-configuration';
    send_key 'alt-s';                                                        # nfs settings tab
    send_key 'alt-f';                                                        # open firewall port
    send_key 'alt-v';                                                        # nfsv4 domain name field
    type_string 'nfs.openqa.suse.de';
    wait_still_screen 4, 4;                                                  # blinking cursor
    save_screenshot;
    send_key 'alt-n';                                                        # nfs shares tab
    send_key 'alt-a';                                                        # add
    wait_still_screen 4;
    send_key 'alt-v';                                                        # NFSV4 share checkbox
    send_key 'alt-s';                                                        # choose NFS server button
    assert_screen 'nis-client-nfs-server';
    send_key 'alt-o';                                                        # OK
    send_key 'alt-r';                                                        # remote directory text field
    type_string '/home/nis_user';
    send_key 'alt-m';                                                        # mount point text field
    type_string '/home/nis_user';
    send_key 'alt-o';                                                        # OK
    assert_screen 'nis-client-nfs-client-configuration';
    send_key 'alt-o';                                                        # OK
    assert_screen 'nis-client-configuration';
    send_key 'alt-f';                                                        # finish
    assert_screen 'yast2_closed_xterm_visible', 90;
    script_run 'mount|grep nfs';                                 # print nfs mounts
    script_run 'echo "nfs is working" > /home/nis_user/test';    # create file with text, will be checked by server
    type_string "killall xterm\n";                               # game over -> xterm
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
