# SUSE's openQA tests
#
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Verify installation starts and is in progress
# Maintainer: Michael Moese <mmoese@suse.de>

package ipxe_install;
use base 'y2_installbase';

use utils;
use testapi;
use bmwqemu;
use ipmi_backend_utils;
use version_utils qw(is_upgrade is_tumbleweed is_sle is_leap is_sle_micro is_agama is_transactional);
use bootloader_setup 'prepare_disks';
use Utils::Architectures;
use Utils::Backends qw(is_ipmi is_qemu);
use autoyast qw(expand_agama_profile);
use virt_autotest::utils qw(is_kvm_host is_xen_host);
use HTTP::Tiny;
use IPC::Run;
use Time::HiRes 'sleep';
use Socket qw(inet_ntoa inet_aton);


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
        diag "setting boot device to pxe";
        my $options = get_var('IPXE_UEFI') ? 'options=efiboot' : '';
        ipmitool("chassis bootdev pxe ${options}");
        sleep(3);
        my $stdout = ipmitool('chassis bootparam get 5');
        last if $stdout =~ m/Force PXE/s;
    }
}

sub set_bootscript {
    my $distri;
    my $version;
    if (get_var('IPXE_BOOT_FIXED')) {
        $distri = get_var('IPXE_BOOT_FIXED_DISTRI', 'sle');
        $version = get_var('IPXE_BOOT_FIXED_VERSION', '15-SP6');
    } else {
        $distri = is_sle_micro('>=6.1') ? "SL-Micro" : get_required_var('DISTRI');
        $version = get_required_var('VERSION');
    }
    my $host = get_required_var('SUT_IP');
    my $arch = get_required_var('ARCH');
    my $autoyast = get_var('AUTOYAST', '');
    my $mirror_http = get_required_var('MIRROR_HTTP');

    # trim all strings from variables to get rid of bogus whitespaces
    $arch =~ s/^\s+|\s+$//g;
    $autoyast =~ s/^\s+|\s+$//g;
    $mirror_http =~ s/^\s+|\s+$//g;

    my $install = "install=$mirror_http";
    my $kernel = $mirror_http;
    my $initrd = $mirror_http;

    if (is_disk_image) {
        $install = "rd.kiwi.install.image=" . get_required_var('MIRROR_HTTP') . "/";
        $install .= get_var('HDD_1') ? get_var('HDD_1') : get_required_var('INSTALL_HDD_IMAGE');
        if (is_sle('>=16.1')) {
            if (is_transactional) {
                $kernel .= "/pxeboot." . uc($distri) . "S-$version-Transactional.$arch-$version.0.kernel";
                $initrd .= "/pxeboot." . uc($distri) . "S-$version-Transactional.$arch-$version.0.initrd";
            }
        }
        else {
            $kernel .= "/pxeboot.$distri.$arch-$version.kernel";
            $initrd .= "/pxeboot.$distri.$arch-$version.initrd";
        }
    } elsif ($arch eq 'aarch64') {
        $kernel .= '/boot/aarch64/linux';
        $initrd .= '/boot/aarch64/initrd';
    } else {
        $kernel .= "/boot/$arch/loader/linux";
        $initrd .= "/boot/$arch/loader/initrd";
    }
    $initrd = "--name " . get_var('BOOTLOADER_INITRD') . " $initrd" if (get_var('BOOTLOADER_INITRD') and is_uefi_boot);

    if (get_var('SUT_NETDEVICE') and !is_tumbleweed) {
        my $interface = get_var('SUT_NETDEVICE');
        $install .= "?device=$interface ifcfg=$interface=dhcp4 ";
    }

    my $cmdline_extra = set_bootscript_cmdline_extra();

    my $bootscript = <<"END_BOOTSCRIPT";
#!ipxe
echo ++++++++++++++++++++++++++++++++++++++++++
echo ++++++++++++ openQA ipxe boot ++++++++++++
echo +    Host: $host
echo ++++++++++++++++++++++++++++++++++++++++++

kernel $kernel $install $cmdline_extra
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

sub set_bootscript_agama {
    my $host = get_required_var('SUT_IP');
    my $arch = get_required_var('ARCH');
    my $mirror_http = get_required_var('MIRROR_HTTP');
    my $install = "root=live:$mirror_http/LiveOS/squashfs.img live.password=$testapi::password";
    my $kernel = "$mirror_http/boot/$arch/loader/linux";
    my $initrd = "$mirror_http/boot/$arch/loader/initrd";

    my $cmdline_extra = set_bootscript_agama_cmdline_extra();

    my $bootscript = <<"END_BOOTSCRIPT";
#!ipxe
echo ++++++++++++++++++++++++++++++++++++++++++
echo +++++++++ openQA agama ipxe boot +++++++++
echo +    Host: $host
echo ++++++++++++++++++++++++++++++++++++++++++

echo Loading kernel
kernel $kernel $install $cmdline_extra
echo Loading initrd
initrd $initrd
sleep 3
echo Starting the installation
boot
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


sub set_bootscript_agama_cmdline_extra {
    my $cmdline_extra = " ";
    if (my $agama_auto = get_var('INST_AUTO')) {
        my $agama_auto_url = autoyast::expand_agama_profile($agama_auto);
        $cmdline_extra .= "inst.auto=$agama_auto_url inst.finish=stop ";
    }
    # Agama Installation repository URL
    # By default Agama installs the packages from the repositories specified in the product configuration.
    # From now Agama supports using the inst.install_url boot parameter for overriding the default installation repositories.
    if (my $agama_install_url = get_var('INST_INSTALL_URL')) {
        $agama_install_url =~ s/^\s+|\s+$//g;
        $cmdline_extra .= "inst.install_url=$agama_install_url ";
    }
    # Add register URL, we don't need to register the system in case:
    #   1. Any install repos are used
    #   2. Register the system via scc, see https://bugzilla.suse.com/show_bug.cgi?id=1246600
    unless (get_var('INST_INSTALL_URL')) {
        if (my $register_url = get_var('HOST_SCC_URL', get_var('SCC_URL'))) {
            $cmdline_extra .= "inst.register_url=$register_url " unless $register_url =~ /https:\/\/scc.suse.com/;
        }
    }
    if (is_ipmi) {
        my $ipxe_console = get_required_var('IPXE_CONSOLE');
        my $sol_console = (split(/,/, $ipxe_console))[0];
        $cmdline_extra .= "console=$ipxe_console linuxrc.log=/dev/$sol_console linuxrc.core=/dev/$sol_console linuxrc.debug=4,trace ";
    }

    # Support passing EXTRA_PXE_CMDLINE and EXTRABOOTPARAMS to bootscripts (inherited from set_bootscript_cmdline_extra)
    $cmdline_extra .= ' ' . get_var('EXTRA_PXE_CMDLINE', '');
    $cmdline_extra .= ' ' . get_var('EXTRABOOTPARAMS', '');
    $cmdline_extra .= ' ' . get_var('AGAMA_NETWORK_PARAMS', '');
    # Pass specific CPU parameters for a particular type of tests
    $cmdline_extra .= ' ' . get_var('CPU_BOOTPARAMS', '') if get_var('ALLOW_CPU_BOOTPARAMS', '');

    return $cmdline_extra;
}

sub set_bootscript_cmdline_extra {
    my $cmdline_extra = " ";
    my $regurl = get_var('VIRT_AUTOTEST') ? get_var('HOST_SCC_URL', '') : get_var('SCC_URL', '');
    my $console = get_var('IPXE_CONSOLE', '');
    my $autoyast = get_var('AUTOYAST', '');

    # trim all strings from variables to get rid of bogus whitespaces
    $regurl =~ s/^\s+|\s+$//g;
    $console =~ s/^\s+|\s+$//g;
    $autoyast =~ s/^\s+|\s+$//g;

    if (is_disk_image) {
        $cmdline_extra .= set_bootscript_image_config();
        $cmdline_extra .= set_bootscript_firstboot_config();
    }
    $cmdline_extra .= " regurl=$regurl " if ($regurl and !is_usb_boot);
    $cmdline_extra .= " console=$console " if $console;
    if (check_var('IPXE_UEFI', '1')) {
        if (!check_var('BOOTLOADER_ROOT_DEVICE', '0')) {
            if (!get_var('BOOTLOADER_ROOT_DEVICE')) {
                $cmdline_extra .= " root=/dev/ram0 ";
            }
            else {
                $cmdline_extra .= " root=" . get_var('BOOTLOADER_ROOT_DEVICE') . " ";
            }
        }
        if (!check_var('BOOTLOADER_INITRD', '0')) {
            if (!get_var('BOOTLOADER_INITRD')) {
                $cmdline_extra .= " initrd=initrd ";
            }
            else {
                $cmdline_extra .= " initrd=" . get_var('BOOTLOADER_INITRD') . " ";
            }
        }
    }
    $cmdline_extra .= " textmode=1 " if get_var('IPXE_UEFI') or check_var('VIDEOMODE', 'text');
    $cmdline_extra .= " self_update=0 " if (check_var("INSTALLER_NO_SELF_UPDATE", 1));

    # Support passing EXTRA_PXE_CMDLINE to bootscripts
    $cmdline_extra .= get_var('EXTRA_PXE_CMDLINE') . ' ' if get_var('EXTRA_PXE_CMDLINE');

    if ($autoyast ne '') {
        $cmdline_extra .= " autoyast=$autoyast sshd=1 sshpassword=$testapi::password ";
    } elsif (!is_disk_image) {
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
    return $cmdline_extra;
}

sub set_bootscript_image_config {

    my $cmdline_image_config =
      " rd.kiwi.install.pxe rd.kiwi.install.pxe.curl_options=--retry,3,--retry-delay,3,--speed-limit,2048"
      . " rd.debug rd.memdebug=5 rd.udev.debug rd.kiwi.debug rd.kiwi.term rd.kiwi.install.pass.bootparam ";
    if (get_var("FIRST_BOOT_CONFIG")) {
        $cmdline_image_config .= " rd.kiwi.oem.installdevice=";
        if (is_ipmi) {
            $cmdline_image_config .=
              get_var('INSTALL_DISK_WWN') ? "/dev/disk/by-id/" . get_var('INSTALL_DISK_WWN') . " " : "/dev/sda ";
            set_var('INSTALL_DISK_WWN', get_var('INSTALL_DISK_WWN', '/dev/sda'));
        }
        elsif (is_qemu) {
            $cmdline_image_config .= "/dev/vda ";
            set_var('INSTALL_DISK_WWN', get_var('INSTALL_DISK_WWN', '/dev/vda'));
        }
    }

    return $cmdline_image_config;
}

sub set_bootscript_firstboot_config {

    my $cmdline_firstboot_config = "";
    my $firstboot_config = get_var("FIRST_BOOT_CONFIG");
    if ($firstboot_config =~ /ignition/ig) {
        $cmdline_firstboot_config .= " ignition.firstboot ignition.config.url=" . get_required_var('IGNITION_PATH');
    }
    if ($firstboot_config =~ /combustion/ig) {
        $cmdline_firstboot_config .= " combustion.firstboot combustion.url=" . get_required_var('COMBUSTION_PATH');
    }

    return $cmdline_firstboot_config;
}

sub run {
    my $self = shift;

    poweroff_host;

    # Note:
    # SLE Micro 6.0 Self-Install image does not directly support pxe boot.
    # To install it on bare metal machine, firstly bring up a minimum system via ipxe
    # with this function(eg sle15sp5 gm). But we do not need to finish installation,
    # booting to sshd-server-started is enough, at which we will have a ssh console
    # to do latter steps.
    # Then dd the Self-Install iso to a USB device.
    # And then boot from the USB, and finish installation with the Self-Install iso.
    # For more details, refer to poo#151498.
    # To achieve the first step, in testsuite settings,
    # - set `IPXE_UEFI`: SLE Micro 6.0+ only officially support uefi boot
    # - set `USB_BOOT`: a flag to indicate this USB installation method,
    #                   which stops further installation
    # - set `MIRROR_HTTP`: the repository to bring up a minimum system(eg sle15sp5 gm)
    # - do NOT set `AUTOYAST`

    die "Can't set AUTOYAST for usb boot!" if (get_var('AUTOYAST', '') && is_usb_boot);

    # virtualization tests use a static ipxe configuration file in O3
    is_agama ? set_bootscript_agama : set_bootscript unless (get_var('IPXE_STATIC'));

    set_pxe_boot;

    poweron_host;

    select_console 'sol', await_console => 0;

    if (is_disk_image) {
        check_screen([qw(load-linux-kernel load-initrd)]);
        return;
    }

    if (get_var('WORKER_CLASS') =~ /ipmi-nvdimm/) {
        assert_screen 'nue-ipxe-menu', 600;
        my $sut_ip = inet_ntoa(inet_aton(get_required_var('SUT_IP')));
        wait_screen_change { send_key 'i' };
        assert_screen 'ipxe-shell';
        # machine has two interfaces with IPs, ipxe detects the first one,
        # but it is not correct, this line is correcting it
        enter_cmd_slow 'chain --replace --autofree ' . get_var('IPXE_HTTPSERVER') . '/' . $sut_ip . '/script.ipxe';
        send_key "ret";
    }

    if (is_agama) {
        assert_screen([qw(load-linux-kernel load-initrd)], 240);
        record_info("Installing", "Please check the expected product is being installed");
        assert_screen('agama-installer-live-root', 400);
        set_bootscript_hdd if get_var('IPXE_SET_HDD_BOOTSCRIPT');
        return;
    }

    # Print screenshots for ipxe boot process
    if (get_var('VIRT_AUTOTEST')) {
        #it is static menu and choose the TW entry to start installation
        enter_o3_ipxe_boot_entry if get_var('IPXE_STATIC');
        check_screen([qw(load-linux-kernel load-initrd)], 80);
        assert_screen([qw(network-config-created loading-installation-system sshd-server-started autoyast-installation)], 300);
        set_bootscript_hdd if get_var('IPXE_SET_HDD_BOOTSCRIPT');
        return if get_var('AUTOYAST');
        wait_still_screen(stilltime => 12, similarity_level => 60, timeout => 30) unless check_screen('sshd-server-started', timeout => 60);
        save_screenshot;
    }

    # when we don't use autoyast, we need to also load the right test modules to perform the remote installation
    unless (get_var('AUTOYAST')) {
        my $ssh_vnc_wait_time = 1500;
        #for virtualization test, 9 minutes is enough to load installation system, 75 minutes is too long
        $ssh_vnc_wait_time = 180 if get_var('VIRT_AUTOTEST');
        my $ssh_vnc_tag = eval { check_var('VIDEOMODE', 'text') ? 'sshd' : 'vnc' } . '-server-started';
        my @tags = ($ssh_vnc_tag);
        if (check_screen(\@tags, $ssh_vnc_wait_time)) {
            save_screenshot;
            sleep 2;
            prepare_disks if (!is_upgrade && !get_var('KEEP_DISKS'));
            return if is_usb_boot;
        }
        else {
            save_screenshot;
            die "Do not catch needle with tag $ssh_vnc_tag!" if is_usb_boot;
        }

        set_bootscript_hdd if get_var('IPXE_SET_HDD_BOOTSCRIPT');

        unless (get_var('HOST_INSTALL_AUTOYAST')) {
            select_console 'installation';
            save_screenshot;
            #It was 'enter_cmd_slow('DISPLAY= yast.ssh') for SLE;'
            #Removing 'DIAPLAY= ' for SLE15SP6 because it resulted in SCC registration failure(bsc#1218798).
            if (check_var('VIDEOMODE', 'text') and is_sle('<=15-SP5')) {
                enter_cmd_slow('DISPLAY= yast.ssh');
            }
            elsif (check_var('VIDEOMODE', 'text') or check_var('VIDEOMODE', 'ssh-x')) {
                enter_cmd_slow("yast.ssh");
            }
            save_screenshot;
            wait_still_screen;
        }
    }
    elsif (get_var('IPXE_SET_HDD_BOOTSCRIPT')) {
        # make sure to wait for a while befor changing the boot device again, in order to not change it too early
        sleep get_var('PXE_BOOT_TIME', 120);
        set_bootscript_hdd;
    }
}

1;

=head1 Configuration

=head2 PXE_BOOT_TIME

The time in seconds that the worker takes from power-on to starting execution
of the PXE script or menu. Default is 120s. Setting the variable too high is
safer than too low.

=cut
