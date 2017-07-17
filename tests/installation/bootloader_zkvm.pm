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

use testapi;
use File::Basename 'basename';

use strict;
use warnings;
use bootloader_setup;


sub run {
    my $svirt    = select_console('svirt', await_console => 0);
    my $name     = $svirt->name;
    my $img_path = "/var/lib/libvirt/images";

    # temporary use of hardcoded '+4' to workaround messed up network setup on z/KVM
    my $vtap = $svirt->instance + 4;
    my $repo = "ftp://openqa.suse.de/" . get_var('REPO_0');


    if (!get_var('BOOT_HDD_IMAGE') or (get_var('PATCHED_SYSTEM') and !get_var('ZDUP'))) {
        my $cmdline = get_var('VIRSH_CMDLINE') . " ";

        $cmdline .= "install=$repo ";

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

        $svirt->change_domain_element(os => initrd  => "$img_path/$name.initrd");
        $svirt->change_domain_element(os => kernel  => "$img_path/$name.kernel");
        $svirt->change_domain_element(os => cmdline => $cmdline);

        # show this on screen and make sure that kernel and initrd are actually saved
        type_string "wget $repo/boot/s390x/initrd -O $img_path/$name.initrd\n";
        assert_screen "initrd-saved";
        type_string "wget $repo/boot/s390x/linux -O $img_path/$name.kernel\n";
        assert_screen "kernel-saved";
    }

    # after installation we need to redefine the domain, so just shutdown
    # on zdup and online migration we don't need to redefine in between
    # If boot from existing hdd image, we don't expect shutdown on reboot
    if (!get_var('ZDUP') and !get_var('ONLINE_MIGRATION') and !get_var('BOOT_HDD_IMAGE')) {
        $svirt->change_domain_element(on_reboot => 'destroy');
    }

    # For some tests we need more than the default 4GB
    my $size_i = get_var('HDDSIZEGB') || '4';

    if (my $hdd = get_var('HDD_1')) {
        my $hdd_dir  = "/var/lib/openqa/share/factory/hdd";
        my $basename = basename($hdd);
        chomp(my $hdd_path = `find $hdd_dir -name $basename | head -n1`);
        diag("HDD path found: $hdd_path");
        if (get_var('PATCHED_SYSTEM')) {
            diag('in patched systems just load the patched image');
            my $patched_img = "$img_path/$name" . "a.img";
            $svirt->add_disk({file => $patched_img, dev_id => 'a'});
        }
        else {
            type_string("# copying image...\n");
            $svirt->add_disk({file => $hdd_path, backingfile => 1, dev_id => 'a'});    # Copy disk to local storage
        }
    }
    else {
        $svirt->add_disk({size => $size_i . "G", create => 1, dev_id => 'a'});
    }
    # need that for s390
    $svirt->add_pty({pty_dev => 'console', pty_dev_type => 'pty', target_type => 'sclp', target_port => '0'});

    # direct access to the tap device
    # use of $vtap temporarily
    $svirt->add_interface({type => 'direct', source => {dev => "enccw0.0.0600", mode => 'bridge'}, target => {dev => 'macvtap' . $vtap}});

    # use proper virtio
    # $svirt->add_interface({ type => 'network', source => { network => 'default' }, model => { type => 'virtio' } });


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
