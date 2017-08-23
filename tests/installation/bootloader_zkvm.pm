# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: zKVM bootloader
# Maintainer: Matthias Grießmeier <mgriessmeier@suse.de>

use base "installbasetest";

use strict;
use warnings;

use bootloader_setup;
use testapi;
use utils 'OPENQA_FTP_URL';

sub set_svirt_domain_elements {
    my ($svirt) = shift;

    if (!get_var('BOOT_HDD_IMAGE') or (get_var('PATCHED_SYSTEM') and !get_var('ZDUP'))) {
        my $repo    = "$utils::OPENQA_FTP_URL/" . get_var('REPO_0');
        my $cmdline = get_var('VIRSH_CMDLINE') . " install=$repo ";
        my $name    = $svirt->name;

        if (check_var("VIDEOMODE", "text")) {
            $cmdline .= "ssh=1 ";    # trigger ssh-text installation
        }
        else {
            $cmdline .= "sshd=1 vnc=1 VNCPassword=$testapi::password ";    # trigger default VNC installation
        }

        # we need ssh access to gather logs
        # 'ssh=1' and 'sshd=1' are equal, both together don't work
        # so let's just set the password here
        $cmdline .= "sshpassword=$testapi::password ";

        if (get_var('UPGRADE')) {
            $cmdline .= "upgrade=1 ";
        }

        if (get_var('AUTOYAST')) {
            $cmdline .= " autoyast=" . data_url(get_var('AUTOYAST')) . " ";
        }

        $cmdline .= specific_bootmenu_params;

        $svirt->change_domain_element(os => initrd  => "$zkvm_img_path/$name.initrd");
        $svirt->change_domain_element(os => kernel  => "$zkvm_img_path/$name.kernel");
        $svirt->change_domain_element(os => cmdline => $cmdline);

        # show this on screen and make sure that kernel and initrd are actually saved
        type_string "wget $repo/boot/s390x/initrd -O $zkvm_img_path/$name.initrd\n";
        assert_screen "initrd-saved";
        type_string "wget $repo/boot/s390x/linux -O $zkvm_img_path/$name.kernel\n";
        assert_screen "kernel-saved";
    }
    # after installation we need to redefine the domain, so just shutdown
    # on zdup and online migration we don't need to redefine in between
    # If boot from existing hdd image, we don't expect shutdown on reboot
    if (!get_var('ZDUP') and !get_var('ONLINE_MIGRATION') and !get_var('BOOT_HDD_IMAGE')) {
        $svirt->change_domain_element(on_reboot => 'destroy');
    }
}

sub run {
    my $svirt = select_console('svirt', await_console => 0);

    set_svirt_domain_elements $svirt;
    zkvm_add_disk $svirt;
    zkvm_add_pty $svirt;
    zkvm_add_interface $svirt;

    $svirt->define_and_start;

    if (!get_var("BOOT_HDD_IMAGE") or (get_var('PATCHED_SYSTEM') and !get_var('ZDUP'))) {
        if (check_var("VIDEOMODE", "text")) {
            wait_serial("run 'yast.ssh'", 300) || die "linuxrc didn't finish";
            select_console("installation");
            type_string("yast.ssh\n");
        }
        else {
            wait_serial(' Starting YaST2 ', 300) || die "yast didn't start";
            select_console('installation');
        }
    }
}

1;
