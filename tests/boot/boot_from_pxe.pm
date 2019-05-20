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

package boot_from_pxe;

use base 'opensusebasetest';
use strict;
use warnings;
use lockapi;
use testapi;
use bootloader_setup qw(bootmenu_default_params specific_bootmenu_params);
use registration 'registration_bootloader_cmdline';
use utils 'type_string_slow';

# Variables are present in vars.json
# IPMI_HOSTNAME, IPMI_USER, IPMI_PASSWORD
sub init_ipmi_vars {
    return {
        hostname => get_required_var('IPMI_HOSTNAME'),
        username => get_required_var('IPMI_USER'),
        userpass => get_required_var('IPMI_PASSWORD')
    };
}

sub create_prefix {
    my $ipmi_host = shift;
    if (defined($ipmi_host)) {
        return ("ipmitool -I lanplus -H $ipmi_host->{hostname} -U $ipmi_host->{username} -P $ipmi_host->{userpass} -v ");
    }
    die "Failed to create prefix!\n";
}

sub reactivate_sol {
    my ($cmd_prefix, $hostname) = @_;
    diag("IPMI Activating SOL on $hostname");
    diag($cmd_prefix . "sol activate\n");
    my $rc = system($cmd_prefix . "sol activate");
    # EXIT_FAILURE of ipmitool
    if ($rc != 0) {
        diag("IPMI deactivate SOL");
        diag($cmd_prefix . "sol deactivate\n");
        system($cmd_prefix . "sol deactivate");
        sleep 1;
        diag("IPMI re-activate SOL");
        diag($cmd_prefix . "sol activate\n");
        system($cmd_prefix . "sol activate");
    }
    diag("IPMI sol info");
    diag($cmd_prefix . "sol info\n");
    system($cmd_prefix . "sol info");
    select_console 'sol', await_console => 0;
}

sub run {
    my $self = shift;
    my ($image_path, $image_name, $cmdline);
    my $arch       = get_var('ARCH');
    my $interface  = get_var('SUT_NETDEVICE', 'eth0');
    my $is_initrd  = 0;
    my $ipmi_host  = init_ipmi_vars;
    my $cmd_prefix = create_prefix($ipmi_host);
    # In autoyast tests we need to wait until pxe is available
    if (get_var('AUTOYAST') && get_var('DELAYED_START') && !check_var('BACKEND', 'ipmi')) {
        mutex_lock('pxe');
        mutex_unlock('pxe');
        resume_vm();
    }
    reactivate_sol($cmd_prefix, $ipmi_host->{hostname}) if (check_var('BACKEND', 'ipmi'));

    # Assert one of QA PXE menus
    assert_screen([qw(virttest-pxe-menu qa-net-selection prague-pxe-menu pxe-menu)], 300);

    # boot bare-metal/IPMI machine
    if (check_var('BACKEND', 'ipmi') && get_var('BOOT_IPMI_SYSTEM')) {
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
            wait_still_screen 5;
            my $path_prefix = "auto/openqa/repo";
            my $path        = "${path_prefix}/${image_name}/boot/${arch}";
            $image_path = "linux $path/linux install=$repo";
            # initrd is not specified yet, let's do it later
            $is_initrd = 1;
        }

        #IPMI Backend
        $image_path .= "?device=$interface " if check_var('BACKEND', 'ipmi');
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
    if (check_var('BACKEND', 'ipmi')) {
        $image_path .= "ipv6.disable=1 " if get_var('LINUX_BOOT_IPV6_DISABLE');
        $image_path .= "ifcfg=$interface=dhcp4 " unless get_var('NETWORK_INIT_PARAM');
        $image_path .= 'plymouth.enable=0 ';
    }
    # Execute installation command on pxe management cmd console
    type_string_slow ${image_path} . " ";
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

    # try to avoid blue screen issue on osd ipmi tests
    # local test passes, if validated on osd, will switch on to all ipmi tests
    if (check_var('BACKEND', 'ipmi') && check_var('VIDEOMODE', 'text') && check_var('VIRT_AUTOTEST', 1)) {
        type_string_slow(" vt.color=0x07 ");
    }

    wait_still_screen(stilltime => 5, timeout => 120, similarity_level => 50);
    send_key 'ret';
    wait_still_screen(stilltime => 5, timeout => 120, similarity_level => 50);
    save_screenshot;

    if (check_var('BACKEND', 'ipmi') && !get_var('AUTOYAST')) {
        if ($is_initrd) {
            assert_screen 'orthos-grub-boot-linux';
            my $image_name = eval { check_var("INSTALL_TO_OTHERS", 1) ? get_var("REPO_0_TO_INSTALL") : get_var("REPO_0") };
            my $args       = "initrd auto/openqa/repo/${image_name}/boot/${arch}/initrd";
            wait_still_screen 5;
            type_string $args;
            send_key 'ret';
            assert_screen 'orthos-grub-boot-initrd', 100;
            $args = "boot";
            type_string $args;
            send_key "ret";
        }
    }
}

sub post_fail_hook {
    my $ipmi_host     = init_ipmi_vars;
    my $cmd_prefix    = create_prefix($ipmi_host);
    my @ipmi_commands = (
        'sel list',
        'sol activate',
        'sol info',
        'chassis power status',
        'chassis selftest',
        'mc getenables',
        'mc selftest',
        'channel info',
        'lan print',
        'session info all'
    );
    diag("IPMI post fail hook data\n");
    foreach (@ipmi_commands) {
        diag("IPMI $_");
        system($cmd_prefix . $_);
    }
}

1;
