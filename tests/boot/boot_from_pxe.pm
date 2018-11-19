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
use utils 'type_string_very_slow';

sub run {
    # In autoyast tests we need to wait until pxe is available
    if (get_var('AUTOYAST') && get_var('DELAYED_START')) {
        mutex_lock('pxe');
        mutex_unlock('pxe');
        resume_vm();
    }
    if (check_var('BACKEND', 'ipmi')) {
        select_console 'sol', await_console => 0;
    }
    assert_screen([qw(virttest-pxe-menu qa-net-selection prague-pxe-menu prague-icecream-pxe-menu pxe-menu)], 300);
    my $image_path = "";
    my $type_speed = 20;
    #detect pxe location
    if (match_has_tag("virttest-pxe-menu")) {
        #BeiJing
        # Login to command line of pxe management
        send_key_until_needlematch "virttest-pxe-edit-prompt", "esc", 60, 1;

        $image_path = get_var("HOST_IMG_URL");
    }
    elsif (match_has_tag("qa-net-selection")) {
        #Nuremberg
        send_key_until_needlematch 'qa-net-boot', 'esc', 8, 3;

        my $image_name = "";
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
        $image_path = "$path/linux initrd=$path/initrd install=$repo";
        if (check_var('BACKEND', 'ipmi')) {
            my $netdevice = get_var('SUT_NETDEVICE', 'eth0');
            $image_path .= "?device=$netdevice";
        }
    }
    elsif (match_has_tag('prague-pxe-menu')) {
        send_key_until_needlematch 'pxe-stable-iso-entry', 'down';
        send_key 'ret';
        send_key_until_needlematch 'pxe-sle-12-sp3-entry', 'down';
        send_key 'tab';
        my $interface = get_var('WORKER_CLASS') eq 'hornet' ? 'eth1' : 'eth4';
        my $node = get_var('WORKER_CLASS');
        type_string "ifcfg=$interface=dhcp4 ", $type_speed;
    }
    elsif (match_has_tag('prague-icecream-pxe-menu')) {
        # Fix problem with sol on ttyS2
        $testapi::serialdev = get_var('SERIALDEV') if get_var('SERIALDEV');
        send_key_until_needlematch 'qa-net-boot', 'esc', 8, 3;

        my $arch = get_var('ARCH');
        my ($image_name) = get_var('ISO') =~ s/^.*?([^\/]+)-DVD-${arch}-([^-]+)-DVD1\.iso/$1-$2/r;
        $image_path .= "/mounts/dist/install/SLP/${image_name}/${arch}/DVD1/boot/${arch}/loader/linux ";
        $image_path .= "initrd=/mounts/dist/install/SLP/${image_name}/${arch}/DVD1/boot/${arch}/loader/initrd ";
        $image_path .= "install=http://mirror.suse.cz/install/SLP/${image_name}/${arch}/DVD1";
    }
    elsif (match_has_tag('pxe-menu')) {
        # select network (second entry)
        send_key "down";
        send_key "tab";
    }
    # Execute installation command on pxe management cmd console
    type_string ${image_path} . " ", $type_speed;
    bootmenu_default_params(pxe => 1, baud_rate => '115200');

    if ((check_var('BACKEND', 'ipmi') && !get_var('AUTOYAST')) || get_var('SES5_DEPLOY')) {
        my $cmdline = '';
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
        type_string $cmdline, $type_speed;
    }

    if (check_var('SCC_REGISTER', 'installation') && !(check_var('VIRT_AUTOTEST', 1) && check_var('INSTALL_TO_OTHERS', 1))) {
        type_string(registration_bootloader_cmdline, $type_speed);
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
            type_string('DISPLAY= ', $type_speed) if check_var('VIDEOMODE', 'text');
            type_string("yast.ssh\n", $type_speed);
        }
        wait_still_screen;
    }
}

1;
