# SUSE's openQA tests
#
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Boot systems from PXE
# Maintainer: alice <xlai@suse.com>

use base 'opensusebasetest';

use strict;
use warnings;
use bootloader_setup;
use File::Basename;
use lockapi;
use registration;
use testapi;
use utils 'type_string_slow';

sub run {
    my $interface = get_var('SUT_NETDEVICE', 'eth0');
    # In autoyast tests we need to wait until pxe is available
    if (get_var('AUTOYAST') && get_var('DELAYED_START')) {
        mutex_lock('pxe');
        mutex_unlock('pxe');
        resume_vm();
    }
    if (check_var('BACKEND', 'ipmi')) {
        select_console 'sol', await_console => 0;
    }
    my $image_path = "";
    assert_screen([qw(pxe-menu-bei pxe-menu-nue pxe-menu-prg pxe-menu)], 300);
    #detect pxe location
    if (match_has_tag('pxe-menu-bei')) {    # BeiJing
        send_key_until_needlematch 'pxe-edit-prompt', 'esc', 60, 1;
        $image_path = get_var("HOST_IMG_URL");
    }
    elsif (match_has_tag('pxe-menu-nue')) {     # Nuremberg
        send_key_until_needlematch 'pxe-edit-prompt', 'esc', 8, 3;
        if (check_var("INSTALL_TO_OTHERS", 1)) {
            $image_name = get_var("REPO_0_TO_INSTALL");
        }
        else {
            $image_name = get_var("REPO_0");
        }

        my $arch       = get_var('ARCH');
        my $path       = "/mnt/openqa/repo/${image_name}/boot/${arch}/loader";
        my $openqa_url = get_required_var('OPENQA_URL');
        $openqa_url = 'http://' . $openqa_url unless $openqa_url =~ /http:\/\//;
        my $repo = $openqa_url . "/assets/repo/${image_name}";
        if (check_var('BACKEND', 'ipmi')) {
            $repo .= "?device=$interface";
        }
        $image_path = "$path/linux initrd=$path/initrd install=$repo ";
    }
        send_key_until_needlematch 'pxe-stable-iso-entry', 'down';
        send_key 'ret';
        send_key_until_needlematch 'pxe-sle-12-sp3-entry', 'down';
        send_key 'tab';
        my $node = get_var('WORKER_CLASS');
    }
        # Fix problem with sol on ttyS2
        $testapi::serialdev = get_var('SERIALDEV') if get_var('SERIALDEV');

        my $arch = get_var('ARCH');
        my ($image_name) = get_var('ISO') =~ s/^.*?([^\/]+)-DVD-${arch}-([^-]+)-DVD1\.iso/$1-$2/r;
        $image_path .= "/mounts/dist/install/SLP/${image_name}/${arch}/DVD1/boot/${arch}/loader/linux ";
        $image_path .= "initrd=/mounts/dist/install/SLP/${image_name}/${arch}/DVD1/boot/${arch}/loader/initrd ";
    elsif (match_has_tag('pxe-menu-prg')) {      # Prague
        send_key_until_needlematch 'pxe-edit-prompt', 'esc', 8, 3;
            my $device = check_var('BACKEND', 'ipmi') ? "?device=$interface" : '';
            $image_path .= "install=http://mirror.suse.cz/install/SLP/${image_name}/${arch}/DVD1$device ";
    }
    elsif (match_has_tag('pxe-menu')) {
        # select network (second entry)
        send_key "down";
        send_key "tab";
    }
    # Execute installation command on pxe management cmd console
    type_string_slow ${image_path};
    bootmenu_default_params(pxe => 1, baud_rate => '115200');

    if (check_var('BACKEND', 'ipmi')) {
        $cmdline = "ifcfg=$interface=dhcp4 plymouth.enable=0 ";
        if (check_var('VIDEOMODE', 'text')) {
            $cmdline .= 'ssh=1 ';    # trigger ssh-text installation
        }
        else {
            $cmdline .= "sshd=1 vnc=1 VNCPassword=$testapi::password ";    # trigger default VNC installation
        }

        # we need ssh access to gather logs
        # 'ssh=1' and 'sshd=1' are equal, both together don't work
        # so let's just set the password here
        $cmdline .= "sshpassword=$testapi::password ";
        type_string_slow $cmdline;
    }

    if (check_var('SCC_REGISTER', 'installation') && !(check_var('VIRT_AUTOTEST', 1) && check_var('INSTALL_TO_OTHERS', 1))) {
        type_string_slow(registration_bootloader_cmdline);
    }

    specific_bootmenu_params;
    send_key 'ret';
    save_screenshot;

    if ((check_var('BACKEND', 'ipmi') && !get_var('AUTOYAST')) || get_var('SES5_DEPLOY')) {
        my $ssh_vnc_wait_time = 600;
        assert_screen((check_var('VIDEOMODE', 'text') ? 'sshd' : 'vnc') . '-server-started', $ssh_vnc_wait_time);
        select_console 'installation';

        # We have textmode installation via ssh and the default vnc installation so far
        if (check_var('VIDEOMODE', 'text') || check_var('VIDEOMODE', 'ssh-x')) {
            type_string_slow('DISPLAY= ') if check_var('VIDEOMODE', 'text');
            type_string_slow("yast.ssh\n");
        }
        wait_still_screen;
    }
}

1;
