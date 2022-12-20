# SUSE's openQA tests
#
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Verify installation starts and is in progress
# Maintainer: Michael Moese <mmoese@suse.de>

use base 'y2_installbase';
use strict;
use warnings;

use utils;
use testapi;
use bmwqemu;
use ipmi_backend_utils;
use version_utils qw(is_upgrade is_tumbleweed);
use bootloader_setup 'prepare_disks';
use Utils::Architectures;

use HTTP::Tiny;
use IPC::Run;
use Socket;
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
        last if $stdout =~ m/Boot Flag Valid[\d\D]*Force PXE/;
        diag "setting boot device to pxe";
        my $options = get_var('IPXE_UEFI') ? 'options=efiboot' : '';
        ipmitool("chassis bootdev pxe ${options}");
        sleep(3);
    }
}

sub set_bootscript {
    my $host = get_required_var('SUT_IP');
    my $ip = inet_ntoa(inet_aton($host));
    my $http_server = get_required_var('IPXE_HTTPSERVER');
    my $url = "$http_server/v1/bootscript/script.ipxe/$ip";
    my $arch = get_required_var('ARCH');
    my $autoyast = get_var('AUTOYAST', '');
    my $regurl = get_var('SCC_URL');
    my $console = get_var('IPXE_CONSOLE');
    my $install = get_required_var('MIRROR_HTTP');

    my $kernel = get_required_var('MIRROR_HTTP');
    my $initrd = get_required_var('MIRROR_HTTP');

    if ($arch eq 'aarch64') {
        $kernel .= '/boot/aarch64/linux';
        $initrd .= '/boot/aarch64/initrd';
    } else {
        $kernel .= "/boot/$arch/loader/linux";
        $initrd .= "/boot/$arch/loader/initrd";
    }


    my $cmdline_extra;
    $cmdline_extra .= " regurl=$regurl " if $regurl;
    $cmdline_extra .= " console=$console " if $console;

    $cmdline_extra .= " root=/dev/ram0 initrd=initrd textmode=1" if check_var('IPXE_UEFI', '1');

    if ($autoyast ne '') {
        $cmdline_extra .= " autoyast=$autoyast ";
    } else {
        $cmdline_extra .= " sshd=1 vnc=1 VNCPassword=$testapi::password sshpassword=$testapi::password ";    # trigger default VNC installation
    }
    $cmdline_extra .= ' plymouth.enable=0 ';

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

    diag "setting iPXE bootscript to: $bootscript";

    if ($autoyast ne '') {
        diag "===== BEGIN autoyast $autoyast =====";
        my $curl = `curl -s $autoyast`;
        diag $curl;
        diag "===== END autoyast $autoyast =====";
    }

    my $response = HTTP::Tiny->new->request('POST', $url, {content => $bootscript, headers => {'content-type' => 'text/plain'}});
    diag "$response->{status} $response->{reason}\n";
}

sub set_bootscript_hdd {
    my $host = get_required_var('SUT_IP');
    my $ip = inet_ntoa(inet_aton($host));
    my $http_server = get_required_var('IPXE_HTTPSERVER');
    my $url = "$http_server/v1/bootscript/script.ipxe/$ip";

    my $bootscript = <<"END_BOOTSCRIPT";
#!ipxe
exit
END_BOOTSCRIPT

    my $response = HTTP::Tiny->new->request('POST', $url, {content => $bootscript, headers => {'content-type' => 'text/plain'}});
    diag "$response->{status} $response->{reason}\n";
}


sub run {
    my $self = shift;

    poweroff_host;

    #virtualization tests use a static ipxe configuration file in O3
    set_bootscript unless get_var('VIRT_AUTOTEST') && is_tumbleweed;

    set_pxe_boot;

    poweron_host;

    select_console 'sol', await_console => 0;

    #use ipxe bootloader in O3
    #it is static menu and choose the TW entry to start installation
    if (get_var('VIRT_AUTOTEST') && is_tumbleweed) {
        ipmitool('chassis power reset') unless check_screen([qw(o3-ipxe-menu ipxe-boot-failure)], 180);
        assert_screen('o3-ipxe-menu', 300);
        send_key 't';
        assert_screen([qw(load-linux-kernel load-initrd)], 240);
        #loading initrd spend much time(fg. 10-15 minutes to Beijing SUT)
        assert_screen([qw(start-tw-install)], 360);
        assert_screen([qw(network-config-created loading-installation-system)], 60);
        wait_still_screen(stilltime => 30, similarity_level => 60, timeout => 120);
        save_screenshot;
    }

    # when we don't use autoyast, we need to also load the right test modules to perform the remote installation
    if (get_var('AUTOYAST')) {
        # make sure to wait for a while before changing the boot device again, in order to not change it too early
        sleep 120;
    } else {
        my $ssh_vnc_wait_time = 1500;
        #for TW virtualization test, 15 minutes is enough to load installation system, 75 minutes is too long
        $ssh_vnc_wait_time = 300 if get_var('VIRT_AUTOTEST') && is_tumbleweed;
        my $ssh_vnc_tag = eval { check_var('VIDEOMODE', 'text') ? 'sshd' : 'vnc' } . '-server-started';
        my @tags = ($ssh_vnc_tag);
        if (check_screen(\@tags, $ssh_vnc_wait_time)) {
            save_screenshot;
            sleep 2;
            prepare_disks if (!is_upgrade && !get_var('KEEP_DISKS'));
        }
        save_screenshot;

        set_bootscript_hdd if get_var('IPXE_UEFI');

        select_console 'installation';
        save_screenshot;

        # We have textmode installation via ssh and the default vnc installation so far
        if (check_var('VIDEOMODE', 'text')) {
            enter_cmd_slow('DISPLAY= yast.ssh');
        }
        elsif (check_var('VIDEOMODE', 'ssh-x')) {
            enter_cmd_slow("yast.ssh");
        }
        save_screenshot;

        wait_still_screen;
    }
}

1;
