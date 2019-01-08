# SUSE's openQA tests
#
# Copyright © 2012-2019 SUSE LLC
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
use lockapi;
use testapi;
use bootloader_setup qw(bootmenu_default_params specific_bootmenu_params);
use registration 'registration_bootloader_cmdline';
use utils 'type_string_slow';

sub run {
    my ($image_path, $image_name, $cmdline);
    my $arch = get_var('ARCH');
    my $interface = get_var('SUT_NETDEVICE', 'eth0');
    # In autoyast tests we need to wait until pxe is available
    if (get_var('AUTOYAST') && get_var('DELAYED_START') && !check_var('BACKEND', 'ipmi')) {
        mutex_lock('pxe');
        mutex_unlock('pxe');
        resume_vm();
    }
    if (check_var('BACKEND', 'ipmi')) {
        select_console 'sol', await_console => 0;
    }
    assert_screen([qw(virttest-pxe-menu qa-net-selection prague-pxe-menu prague-icecream-pxe-menu pxe-menu)], 300);
    #detect pxe location
    if (match_has_tag("virttest-pxe-menu")) {
        #BeiJing
        # Login to command line of pxe management
        send_key_until_needlematch "virttest-pxe-edit-prompt", "esc", 60, 1;

        $image_path = get_var("HOST_IMG_URL");
    }
    elsif (match_has_tag("qa-net-selection")) {
        if (check_var("INSTALL_TO_OTHERS", 1)) {
            $image_name = get_var("REPO_0_TO_INSTALL");
        }
        else {
            $image_name = get_var("REPO_0");
        }

        my $openqa_url = get_required_var('OPENQA_URL');
        $openqa_url = 'http://' . $openqa_url unless $openqa_url =~ /http:\/\//;
        my $repo = $openqa_url . "/assets/repo/${image_name}";
        send_key_until_needlematch [qw(qa-net-boot orthos-grub-boot)], 'esc', 8, 3;
        if (match_has_tag("qa-net-boot")) {
            #Nuremberg
            my $path_prefix = "/mnt/openqa/repo";
            my $path        = "${path_prefix}/${image_name}/boot/${arch}/loader";
            $image_path = "$path/linux initrd=$path/initrd install=$repo";
        }
        elsif (match_has_tag("orthos-grub-boot")) {
            #Orthos
            my $path_prefix = "auto/openqa/repo";
            my $path        = "${path_prefix}/${image_name}/boot/${arch}";
            $image_path = "linux $path/linux install=$repo";
        }

        #IPMI Backend
        $image_path .= "?device=$interface" if check_var('BACKEND', 'ipmi');
    }
    elsif (match_has_tag('prague-pxe-menu')) {
        send_key_until_needlematch 'qa-net-boot', 'esc', 8, 3;
        if (get_var('PXE_ENTRY')) {
            my $entry = get_var('PXE_ENTRY');
            send_key_until_needlematch "pxe-$entry-entry", 'down';
            send_key 'tab';
        }
        else {
            my $device = check_var('BACKEND', 'ipmi') ? "?device=$interface" : '';
            my $release = get_var('BETA') ? 'LATEST' : 'GM';
            $image_name = get_var('ISO') =~ s/.*\/(.*)-DVD-${arch}-.*\.iso/$1-$release/r;
            $image_path = "/mounts/dist/install/SLP/${image_name}/${arch}/DVD1/boot/${arch}/loader/linux ";
            $image_path .= "initrd=/mounts/dist/install/SLP/${image_name}/${arch}/DVD1/boot/${arch}/loader/initrd ";
            $image_path .= "install=http://mirror.suse.cz/install/SLP/${image_name}/${arch}/DVD1$device ";
        }
    }
    elsif (match_has_tag('pxe-menu')) {
        # select network (second entry)
        send_key "down";
        send_key "tab";
    }
    if (check_var('BACKEND', 'ipmi')) {
        $image_path .= "ifcfg=$interface=dhcp4 " unless get_var('NETWORK_INIT_PARAM');
        $image_path .= 'plymouth.enable=0 ';
    }
    # Execute installation command on pxe management cmd console
    type_string_slow ${image_path};
    bootmenu_default_params(pxe => 1, baud_rate => '115200');

    if (check_var('BACKEND', 'ipmi') && !get_var('AUTOYAST')) {
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

    if (check_var('BACKEND', 'ipmi') && !get_var('AUTOYAST')) {
        my $ssh_vnc_wait_time = 300;
        my $ssh_vnc_tag       = eval { check_var('VIDEOMODE', 'text') ? 'sshd' : 'vnc' } . '-server-started';
        my @tags              = ($ssh_vnc_tag, 'orthos-grub-boot-linux');
        assert_screen \@tags, $ssh_vnc_wait_time;

        if (match_has_tag("orthos-grub-boot-linux")) {
            my $image_name = eval { check_var("INSTALL_TO_OTHERS", 1) ? get_var("REPO_0_TO_INSTALL") : get_var("REPO_0") };
            my $args = "initrd auto/openqa/repo/${image_name}/boot/${arch}/initrd";
            type_string $args;
            send_key 'ret';
            assert_screen 'orthos-grub-boot-initrd', $ssh_vnc_wait_time;
            $args = "boot";
            type_string $args;
            send_key "ret";
            assert_screen $ssh_vnc_tag, $ssh_vnc_wait_time;
        }

        select_console 'installation';
        save_screenshot;
        # We have textmode installation via ssh and the default vnc installation so far
        if (check_var('VIDEOMODE', 'text') || check_var('VIDEOMODE', 'ssh-x')) {
            type_string_slow('DISPLAY= ') if check_var('VIDEOMODE', 'text');
            type_string_slow("yast.ssh\n");
        }
        wait_still_screen;
    }
}

1;
