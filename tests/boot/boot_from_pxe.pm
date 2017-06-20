# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Boot systems from PXE
# Maintainer: alice <xlai@suse.com>

use strict;
use warnings;
use File::Basename;
use base "opensusebasetest";
use testapi;

sub run() {
    if (check_var('BACKEND', 'ipmi')) {
        select_console 'sol', await_console => 0;
    }
    assert_screen([qw(virttest-bootloader qa-net-selection)], 300);
    my $image_path = "";

    #detect pxe location
    if (match_has_tag("virttest-bootloader")) {
        #BeiJing
        # Wait the second screen for ipmi bootloader
        send_key_until_needlematch "virttest-boot-into-pxe", "f12", 3, 60;

        # Wait pxe management screen
        send_key_until_needlematch "virttest-pxe-menu", "f12", 200, 1;

        # Login to command line of pxe management
        send_key_until_needlematch "virttest-pxe-edit-prompt", "esc", 60, 1;

        $image_path = get_var("HOST_IMG_URL");
    }
    elsif (match_has_tag("qa-net-selection")) {
        #Numburg
        #send_key_until_needlematch "qa-net-selection-" . get_var('DISTRI') . "-" . get_var("VERSION"), 'down', 30, 3;
        #Don't use send_key_until_needlematch to pick first menu tier as dist network sources might not be ready when openQA is running tests
        send_key 'esc';
        assert_screen 'qa-net-boot';

        my $image_name = "";
        if (check_var("INSTALL_TO_OTHERS", 1)) {
            $image_name = get_var("REPO_0_TO_INSTALL");
        }
        else {
            $image_name = get_var("REPO_0");
        }

        my $arch = get_var('ARCH');
        my $path = "/mnt/openqa/repo/${image_name}/boot/${arch}/loader";
        my $repo = get_required_var('OPENQA_URL') . "/assets/repo/${image_name}";
        $image_path = "$path/linux initrd=$path/initrd install=$repo";
    }

    my $type_speed = 20;
    # Execute installation command on pxe management cmd console
    type_string ${image_path} . " ", $type_speed;
    type_string "vga=791 ",   $type_speed;
    type_string "Y2DEBUG=1 ", $type_speed;

    if (check_var('BACKEND', 'ipmi')) {
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
        type_string $cmdline;
    }

    if (check_var("INSTALL_TO_OTHERS", 1)) {
        type_string "video=1024x768-16 ", $type_speed;
    }
    else {
        type_string "xvideo=1024x768 ", $type_speed;
    }

    type_string "console=$serialdev,115200 ", $type_speed;    # to get crash dumps as text
    type_string "console=tty ",               $type_speed;

    save_screenshot;
    assert_screen 'qa-net-typed';
    my $e = get_var("EXTRABOOTPARAMS");
    if ($e) {
        type_string "$e ", 4;
        save_screenshot;
    }
    send_key 'ret';
    save_screenshot;

    if (check_var('BACKEND', 'ipmi')) {
        assert_screen 'sshd-server-started', 300;
        select_console 'installation';

        # We have textmode installation via ssh and the default vnc installation so far
        if (check_var('VIDEOMODE', 'text') || check_var('VIDEOMODE', 'ssh-x')) {
            type_string('DISPLAY= ') if check_var('VIDEOMODE', 'text');
            type_string("yast.ssh\n");
        }
        wait_still_screen;
    }
}

1;
