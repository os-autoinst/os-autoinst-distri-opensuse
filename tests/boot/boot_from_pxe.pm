#
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Boot systems from PXE
# Maintainer: alice <xlai@suse.com>

package boot_from_pxe;

use base 'opensusebasetest';

use strict;
use warnings;
use lockapi;
use testapi;
use bootloader_setup qw(bootmenu_default_params specific_bootmenu_params prepare_disks sync_time);
use registration 'registration_bootloader_cmdline';
use utils qw(type_string_slow enter_cmd_slow);
use Utils::Backends;
use Utils::Architectures;
use version_utils qw(is_upgrade is_sle);
use ipmi_backend_utils 'set_pxe_boot';

sub run {
    my ($image_path, $image_name, $cmdline);
    my $arch = get_var('ARCH');
    my $interface = get_var('SUT_NETDEVICE', 'eth0');
    # In autoyast tests we need to wait until pxe is available
    if (get_var('AUTOYAST') && get_var('DELAYED_START') && !is_ipmi) {
        mutex_lock('pxe');
        mutex_unlock('pxe');
        resume_vm();
    }

    set_pxe_boot if get_var('UEFI_PXE_BOOT');

    if (is_ipmi) {
        if (is_remote_backend && is_aarch64 && get_var('IPMI_HW') eq 'thunderx') {
            select_console 'sol', await_console => 1;
            send_key 'ret';
            ipmi_backend_utils::ipmitool 'chassis power reset';
        }
        else {
            select_console 'sol', await_console => 0;
        }
    }
    if (!check_screen([qw(virttest-pxe-menu qa-net-selection qa-net-selection-uefi prague-pxe-menu pxe-menu)], 600)) {    # nocheck: old code, should be updated
        ipmi_backend_utils::ipmitool 'chassis power reset';
    }
    assert_screen([qw(virttest-pxe-menu qa-net-selection qa-net-selection-uefi prague-pxe-menu pxe-menu)], 600);

    # boot bare-metal/IPMI machine
    if (is_ipmi && get_var('BOOT_IPMI_SYSTEM')) {
        send_key 'ret';
        assert_screen 'linux-login', 100;
        return 1;
    }
    #detect pxe location
    if (match_has_tag("virttest-pxe-menu")) {
        #BeiJing
        # Login to command line of pxe management
        send_key_until_needlematch "virttest-pxe-edit-prompt", "esc", 60, 1;

        $image_path = get_var("HOST_IMG_URL");
    }
    # the tags, 'qa-net-selection' & 'qa-net-selection-uefi', are expected to be used
    # in the needles for UEFI boot menu in QA-NET, though they are treated differently here
    # because 'qa-net-selection' is widely used
    elsif (match_has_tag("qa-net-selection") or match_has_tag("qa-net-selection-uefi")) {
        if (check_var("INSTALL_TO_OTHERS", 1)) {
            $image_name = get_var("REPO_0_TO_INSTALL");
        }
        else {
            $image_name = get_var("REPO_0");
        }

        my $openqa_url = get_required_var('OPENQA_URL');
        $openqa_url = 'http://' . $openqa_url unless $openqa_url =~ /http:\/\//;
        my $repo = $openqa_url . "/assets/repo/${image_name}";
        my $key_used = '';
        if ((is_remote_backend && is_aarch64 && is_supported_suse_domain) or match_has_tag("qa-net-selection-uefi")) {
            $key_used = 'c';
            send_key 'down';
        }
        else {
            $key_used = 'esc';
        }
        #Detect orthos-grub-boot and qa-net-grub-boot for aarch64 in orthos and openQA networks respectively, and qa-net-boot for x86_64 in openQA network
        send_key_until_needlematch [qw(qa-net-boot orthos-grub-boot qa-net-grub-boot)], $key_used, 8, 3;
        if (match_has_tag("qa-net-boot")) {
            #Nuremberg
            my $path_prefix = "/mnt/openqa/repo";
            my $path = "${path_prefix}/${image_name}/boot/${arch}/loader";
            $image_path = "$path/linux initrd=$path/initrd install=$repo";
        }
        elsif (match_has_tag("orthos-grub-boot") or match_has_tag("qa-net-grub-boot")) {
            #Orthos
            wait_still_screen 5;
            my $path_prefix = "auto/openqa/repo";
            $path_prefix = "/mnt/openqa/repo" if (!is_orthos_machine);
            my $path = "${path_prefix}/${image_name}/boot/${arch}";
            $path .= "/loader" if is_x86_64 && !is_orthos_machine;
            $image_path = "linux $path/linux install=$repo";
        }

        #IPMI Backend
        $image_path .= "?device=$interface " if (is_ipmi && !get_var('SUT_NETDEVICE_SKIPPED'));
    }
    elsif (match_has_tag('prague-pxe-menu')) {
        send_key_until_needlematch 'qa-net-boot', 'esc', 8, 3;
        if (get_var('PXE_ENTRY')) {
            my $entry = get_var('PXE_ENTRY');
            send_key_until_needlematch "pxe-$entry-entry", 'down';
            send_key 'tab';
        }
        else {
            my $device = (is_ipmi && !get_var('SUT_NETDEVICE_SKIPPED')) ? "?device=$interface" : '';
            my $release = get_var('BETA') ? 'LATEST' : 'GM';
            $image_name = get_var('ISO') =~ s/(.*\/)?(.*)-DVD-${arch}-.*\.iso/$2-$release/r;
            $image_name = get_var('PXE_PRODUCT_NAME') if get_var('PXE_PRODUCT_NAME');
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
    if (is_ipmi) {
        $image_path .= " ipv6.disable=1 " if get_var('LINUX_BOOT_IPV6_DISABLE');
        $image_path .= " ifcfg=$interface=dhcp4 " if (!get_var('NETWORK_INIT_PARAM') && !get_var('SUT_NETDEVICE_SKIPPED'));
        $image_path .= ' plymouth.enable=0 ';
    }
    # Execute installation command on pxe management cmd console
    type_string_slow ${image_path} . " ";
    bootmenu_default_params(pxe => 1, baud_rate => '115200');

    if (is_ipmi && !get_var('AUTOYAST')) {
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

        # add extra parameter if needed, such as workaround
        if (get_var("EXTRA_PXE_CMDLINE")) {
            $cmdline .= get_var("EXTRA_PXE_CMDLINE") . ' ';
        }

        type_string_slow $cmdline;
    }

    if (check_var('SCC_REGISTER', 'installation') && !(check_var('VIRT_AUTOTEST', 1) && check_var('INSTALL_TO_OTHERS', 1))) {
        type_string_slow(registration_bootloader_cmdline);
    }

    specific_bootmenu_params;

    # try to avoid blue screen issue on osd ipmi tests
    # local test passes, if validated on osd, will switch on to all ipmi tests
    if (is_ipmi && check_var('VIDEOMODE', 'text') && check_var('VIRT_AUTOTEST', 1)) {
        type_string_slow(" vt.color=0x07 ");
    }

    send_key 'ret';
    save_screenshot;

    # If the remote repo doesn't exist, the machine will silently boot
    # from disk.
    die 'PXE boot failed, installation repository likely does not exist'
      if (check_screen('pxe-kernel-not-found', timeout => 5));

    if (is_ipmi && !get_var('AUTOYAST')) {
        my $ssh_vnc_wait_time = 420;
        my $ssh_vnc_tag = eval { check_var('VIDEOMODE', 'text') ? 'sshd' : 'vnc' } . '-server-started';
        #Detect orthos-grub-boot-linux and qa-net-grub-boot-linux for aarch64 in orthos and openQA networks respectively
        my @tags = ($ssh_vnc_tag, 'orthos-grub-boot-linux', 'qa-net-grub-boot-linux');

        # Proceed if the 'installation' console is ready
        # otherwise the 'sol' console may be just freezed
        my $stilltime = check_var('SLE_PRODUCT', 'sles4sap') ? 30 : 180;
        wait_still_screen(stilltime => $stilltime, timeout => 185);
        if (check_screen(\@tags, $ssh_vnc_wait_time)) {
            save_screenshot;
            sleep 2;
            if (match_has_tag("orthos-grub-boot-linux") or match_has_tag("qa-net-grub-boot-linux")) {
                my $image_name = eval { check_var("INSTALL_TO_OTHERS", 1) ? get_var("REPO_0_TO_INSTALL") : get_var("REPO_0") };
                my $args = "initrd auto/openqa/repo/${image_name}/boot/${arch}/initrd";
                if (!is_orthos_machine) {
                    $args = "initrd /mnt/openqa/repo/${image_name}/boot/${arch}";
                    $args .= "/loader" if is_x86_64;
                    $args .= "/initrd";
                }
                type_string_slow $args;
                send_key 'ret';
                #Detect orthos-grub-boot-initrd and qa-net-grub-boot-initrd for aarch64 in orthos and openQA networks respectively
                wait_still_screen(stilltime => 480, timeout => 485);
                assert_screen [qw(orthos-grub-boot-initrd qa-net-grub-boot-initrd)], $ssh_vnc_wait_time;
                $args = "boot";
                type_string_slow $args;
                send_key "ret";
                assert_screen $ssh_vnc_tag, $ssh_vnc_wait_time;
            }
        }
        sync_time if is_sle('15+');
        if (!is_upgrade && !get_var('KEEP_DISKS')) {
            prepare_disks;
        }
        save_screenshot;
        select_console 'installation';
        save_screenshot;
        # We have textmode installation via ssh and the default vnc installation so far
        if (check_var('VIDEOMODE', 'text') || check_var('VIDEOMODE', 'ssh-x')) {
            type_string_slow('DISPLAY= ') if check_var('VIDEOMODE', 'text');
            enter_cmd_slow("yast.ssh");
        }
        wait_still_screen;
    }
}

sub post_fail_hook {
    my $self = shift;

    if (is_ipmi && check_var('VIDEOMODE', 'text')) {
        select_console 'log-console';
        save_screenshot;
        script_run "save_y2logs /tmp/y2logs_clone.tar.bz2";
        upload_logs "/tmp/y2logs_clone.tar.bz2";
        save_screenshot;
    }

    $self->SUPER::post_fail_hook();
}


1;
