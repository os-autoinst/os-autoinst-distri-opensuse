# SUSE's openQA tests
#
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Verify installation starts and is in progress
# Maintainer: Michael Moese <mmoese@suse.de>

package ipxe_install;
use base 'y2_installbase';
use strict;
use warnings;

use utils;
use testapi;
use bmwqemu;
use ipmi_backend_utils;
use version_utils qw(is_upgrade is_tumbleweed is_sle is_leap);
use bootloader_setup 'prepare_disks';
use Utils::Architectures;
use virt_autotest::utils qw(is_kvm_host is_xen_host);

use HTTP::Tiny;
use IPC::Run;
use Time::HiRes 'sleep';


sub poweroff_host {
    ipmitool("chassis power off");
    while (1) {
        sleep(3);
        my $stdout = ipmitool('chassis power status');
        last if $stdout =~ m/is off/;
        ipmitool('chassis power off');
    }
}

sub poweron_host {
    ipmitool("chassis power on");
    while (1) {
        sleep(3);
        my $stdout = ipmitool('chassis power status');
        last if $stdout =~ m/is on/;
        ipmitool('chassis power on');
    }
}

sub set_pxe_boot {
    while (1) {
        my $stdout = ipmitool('chassis bootparam get 5');
        last if $stdout =~ m/Boot Flag Valid.*Force PXE/s;
        diag "setting boot device to pxe";
        my $options = get_var('IPXE_UEFI') ? 'options=efiboot' : '';
        ipmitool("chassis bootdev pxe ${options}");
        sleep(3);
    }
}

sub set_bootscript {
    my $host = get_required_var('SUT_IP');
    my $arch = get_required_var('ARCH');
    my $autoyast = get_var('AUTOYAST', '');
    my $regurl = get_var('SCC_URL', '');
    my $console = get_var('IPXE_CONSOLE', '');
    my $mirror_http = get_required_var('MIRROR_HTTP');

    # trim all strings from variables to get rid of bogus whitespaces
    $arch =~ s/^\s+|\s+$//g;
    $autoyast =~ s/^\s+|\s+$//g;
    $regurl =~ s/^\s+|\s+$//g;
    $console =~ s/^\s+|\s+$//g;
    $mirror_http =~ s/^\s+|\s+$//g;

    my $install = $mirror_http;
    my $kernel = $mirror_http;
    my $initrd = $mirror_http;

    if ($arch eq 'aarch64') {
        $kernel .= '/boot/aarch64/linux';
        $initrd .= '/boot/aarch64/initrd';
    } else {
        $kernel .= "/boot/$arch/loader/linux";
        $initrd .= "/boot/$arch/loader/initrd";
    }

    if (get_var('SUT_NETDEVICE') and !is_tumbleweed) {
        my $interface = get_var('SUT_NETDEVICE');
        $install .= "?device=$interface ifcfg=$interface=dhcp4 ";
    }

    my $cmdline_extra;
    $cmdline_extra .= " regurl=$regurl " if $regurl;
    $cmdline_extra .= " console=$console " if $console;

    # Support passing both EXTRA_PXE_CMDLINE to bootscripts
    $cmdline_extra .= get_var('EXTRA_PXE_CMDLINE') . ' ' if get_var('EXTRA_PXE_CMDLINE');
    $cmdline_extra .= " root=/dev/ram0 initrd=initrd textmode=1" if check_var('IPXE_UEFI', '1');

    if ($autoyast ne '') {
        $cmdline_extra .= " autoyast=$autoyast sshd=1 sshpassword=$testapi::password ";
    } else {
        $cmdline_extra .= " ssh=1 sshpassword=$testapi::password ";
        $cmdline_extra .= " vnc=1 VNCPassword=$testapi::password " unless check_var('VIDEOMODE', 'text');
    }
    $cmdline_extra .= " plymouth.enable=0 ";

    $cmdline_extra .= " video=1024x768 vt.color=0x07 " if check_var('VIDEOMODE', 'text');
    # Support either IPXE_CONSOLE=ttyS1,115200 or SERIALDEV=ttyS1
    my $serial_dev;
    if (get_var('IPXE_CONSOLE')) {
        get_var('IPXE_CONSOLE') =~ /^(\w+)/;
        $serial_dev = $1;
    }
    else {
        $serial_dev = get_var('SERIALDEV', 'ttyS1');
        $cmdline_extra .= " console=$serial_dev,115200 ";
    }

    # Extra options for virtualization tests with ipmi backend
    $cmdline_extra .= " Y2DEBUG=1 linuxrc.log=/dev/$serial_dev linuxrc.core=/dev/$serial_dev linuxrc.debug=4,trace ";
    $cmdline_extra .= " reboot_timeout=" . get_var('REBOOT_TIMEOUT', 0) . ' '
      unless (is_leap('<15.2') || is_sle('<15-SP2'));
    $cmdline_extra .= get_var('EXTRABOOTPARAMS', '');

    my $bootscript = <<"END_BOOTSCRIPT";
#!ipxe
echo ++++++++++++++++++++++++++++++++++++++++++
echo ++++++++++++ openQA ipxe boot ++++++++++++
echo +    Host: $host
echo ++++++++++++++++++++++++++++++++++++++++++

kernel $kernel install=$install $cmdline_extra
initrd $initrd
boot
END_BOOTSCRIPT

    if ($autoyast ne '') {
        diag "===== BEGIN autoyast $autoyast =====";
        my $curl = `curl -s $autoyast`;
        diag $curl;
        diag "===== END autoyast $autoyast =====";
    }

    set_ipxe_bootscript($bootscript);
}

sub set_bootscript_hdd {
    my $bootscript = <<"END_BOOTSCRIPT";
#!ipxe
exit
END_BOOTSCRIPT

    set_ipxe_bootscript($bootscript);
}

sub enter_o3_ipxe_boot_entry {
    ipmitool('chassis power reset') unless check_screen([qw(o3-ipxe-menu ipxe-boot-failure)], 180);
    assert_screen('o3-ipxe-menu', 210);
    my $key = get_var('HOST_INSTALL_AUTOYAST') ? (is_kvm_host ? 'k' : 'z') : 't';
    send_key "$key";
    # try one more time as sometimes sending key does not take effect
    send_key "$key" if check_screen('o3-ipxe-menu');
    # confirm the dialog asking for user modifications to kernel, cmdline and initrd
    # set limit to 10 in case some keys don't go through
    for (1 .. 10) {
        last if check_screen([qw(load-linux-kernel load-initrd)], 3);
        send_key "ret";
    }
}


sub run {
    my $self = shift;

    poweroff_host;

    #virtualization tests use a static ipxe configuration file in O3
    set_bootscript unless get_var('IPXE_STATIC');

    set_pxe_boot;

    poweron_host;

    select_console 'sol', await_console => 0;

    # Print screenshots for ipxe boot process
    if (get_var('VIRT_AUTOTEST')) {
        #it is static menu and choose the TW entry to start installation
        enter_o3_ipxe_boot_entry if get_var('IPXE_STATIC');
        assert_screen([qw(load-linux-kernel load-initrd)], 240);
        # Loading initrd spend much time(fg. 10-15 minutes to Beijing SUT)
        # Downloading from O3 became much more quick, some needles may not be caught.
        check_screen([qw(start-tw-install start-sle-install network-config-created)], 60);
        if (match_has_tag('start-tw-install')) {
            record_info("Install TW", "Start installing Tumbleweed...");
        }
        elsif (match_has_tag('start-sle-install')) {
            record_info("Install SLE", "Start installing SLE...");
        }
        else {
            record_info("Install others?", "Pls make sure the product that is expected to be installed.");
        }
        assert_screen([qw(network-config-created loading-installation-system sshd-server-started autoyast-installation)], 300);
        return if get_var('AUTOYAST');
        wait_still_screen(stilltime => 12, similarity_level => 60, timeout => 30) unless check_screen('sshd-server-started', timeout => 60);
        save_screenshot;
    }

    # when we don't use autoyast, we need to also load the right test modules to perform the remote installation
    if (get_var('AUTOYAST')) {
        # VIRT_AUTOTEST need not sleep and set_bootscript_hdd
        return if get_var('VIRT_AUTOTEST');
        # HANA PERF uses DELL R840 and R740, their UEFI IPXE boot need not set_bootscript_hdd
        return if (get_var('HANA_PERF') && get_var('IPXE_UEFI'));
        # make sure to wait for a while befor changing the boot device again, in order to not change it too early
        sleep 120;
        set_bootscript_hdd if get_var('IPXE_UEFI');
    }
    else {
        my $ssh_vnc_wait_time = 1500;
        #for virtualization test, 9 minutes is enough to load installation system, 75 minutes is too long
        $ssh_vnc_wait_time = 180 if get_var('VIRT_AUTOTEST');
        my $ssh_vnc_tag = eval { check_var('VIDEOMODE', 'text') ? 'sshd' : 'vnc' } . '-server-started';
        my @tags = ($ssh_vnc_tag);
        if (check_screen(\@tags, $ssh_vnc_wait_time)) {
            save_screenshot;
            sleep 2;
            prepare_disks if (!is_upgrade && !get_var('KEEP_DISKS'));
        }
        save_screenshot;

        set_bootscript_hdd if get_var('IPXE_UEFI');

        unless (get_var('HOST_INSTALL_AUTOYAST')) {
            select_console 'installation';
            save_screenshot;
            if (check_var('VIDEOMODE', 'ssh-x') or is_tumbleweed) {
                enter_cmd_slow("yast.ssh");
            }
            elsif (check_var('VIDEOMODE', 'text')) {
                enter_cmd_slow('DISPLAY= yast.ssh');
            }
            save_screenshot;
            wait_still_screen;
        }
    }
}

1;
