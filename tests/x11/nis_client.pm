# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
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
use warnings;
use testapi;
use lockapi 'mutex_lock';
use utils 'systemctl';
use version_utils 'is_sle';
use y2x11test qw(setup_static_mm_network %setup_nis_nfs_x11);
use x11utils 'turn_off_gnome_screensaver';

sub setup_nis_client {
    if (is_sle('>=15')) {
        assert_screen 'nis-client-install-missing-package';
        send_key 'alt-i';    # install missing ypbind rpm
    }
    assert_screen 'nis-client-configuration', 120;
    send_key 'alt-u';        # use NIS radio button
    wait_still_screen 4;
    send_key 'alt-l';        # open firewall port
    assert_screen 'nis-client-fw-opened';
    send_key 'alt-i';        # NIS domain
    type_string $setup_nis_nfs_x11{nis_domain};
    send_key 'alt-m';        # start automounter
    wait_still_screen 4;
    send_key 'alt-d';        # find NIS server
    assert_screen 'nis-client-server-in-domain', 120;
    send_key 'spc';          # select found NIS server
    assert_screen 'nis-client-server-in-domain-selected';
    send_key 'alt-o';        # OK
    save_screenshot;
}

sub nfs_settings_tab {
    assert_screen 'nis-client-enter-nfs-configuration';
    send_key 'alt-s';        # nfs configuation button
    assert_screen 'nis-client-nfs-client-configuration';
    send_key 'alt-s';        # nfs settings tab
    assert_screen 'nis-client-nfs-settings-tab';
    send_key 'alt-v';        # nfsv4 domain name field
    type_string $setup_nis_nfs_x11{nfs_domain};
    send_key 'alt-f';        # open firewall port
    assert_screen 'nis-client-nfs-settings-tab-opened-fw';
    wait_still_screen 4, 4;    # blinking cursor
    save_screenshot;
}

sub nfs_shares_tab {
    send_key 'alt-n';          # nfs shares tab
    assert_screen 'nis-client-nfs-client-shares-conf';
    send_key 'alt-a';          # add
    wait_still_screen 4;
    send_key 'alt-v';          # NFSV4 share checkbox
    send_key 'alt-s';          # choose NFS server button
    assert_screen 'nis-client-nfs-server';
    send_key 'alt-o';          # OK
    send_key 'alt-r';          # remote directory text field
    type_string $setup_nis_nfs_x11{nfs_dir};
    send_key 'alt-m';          # mount point text field
    type_string $setup_nis_nfs_x11{nfs_dir};
    send_key 'alt-o';          # OK
    assert_screen 'nis-client-nfs-client-configuration';
    send_key 'alt-o';          # OK
    assert_screen 'nis-client-fw-opened';
    send_key 'alt-f';          # finish
}

sub setup_verification {
    assert_screen 'yast2_closed_xterm_visible', 90;
    script_run 'mount|grep nfs';    # print nfs mounts
    if (is_sle('>=15')) {
        record_soft_failure('bsc#1090886');
        script_run("mount -vt nfs $setup_nis_nfs_x11{nfs_dir}");
        script_run 'mount|grep nfs';    # verify mounted nfs
    }
    (my $server_ip = $setup_nis_nfs_x11{server_address}) =~ m/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/;
    script_run "cat /proc/mounts | grep -i $server_ip:";
    # create file with text, will be checked by server
    script_run 'echo ' . $setup_nis_nfs_x11{message} . " > " . $setup_nis_nfs_x11{nfs_dir} . '/test';
}

sub run {
    my ($self) = @_;
    x11_start_program('xterm -geometry 155x45+5+5', target_match => 'xterm');
    turn_off_gnome_screensaver if check_var('DESKTOP', 'gnome');
    become_root;
    setup_static_mm_network($setup_nis_nfs_x11{client_address});
    assert_script_run 'zypper -n in yast2-nis-server';

    if ($self->firewall eq 'firewalld') {
        record_soft_failure('bsc#1083487');
        my $firewalld_ypbind_service = get_test_data('x11/workaround_ypbind.xml');
        type_string("echo \"$firewalld_ypbind_service\" > /usr/lib/firewalld/services/ypbind.xml\n");
        assert_script_run('firewall-cmd --reload');
    }

    if (is_sle) {
        systemctl 'stop ' . $self->firewall;
        record_soft_failure('bsc#999873');
    }

    mutex_lock('nis_ready');    # wait for NIS server setup
    my $module_name = y2logsstep::yast2_console_exec(yast2_module => 'nis');
    setup_nis_client();
    mutex_lock('nfs_ready');    # wait for NFS server setup
    nfs_settings_tab();
    nfs_shares_tab();
    wait_serial("$module_name-0", 360) || die "'yast2 nis client' didn't finish";
    setup_verification();
    type_string "killall xterm\n";    # game over -> xterm
}

1;
