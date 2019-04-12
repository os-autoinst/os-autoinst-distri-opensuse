# SUSE's SLES4SAP openQA tests
#
# Copyright (C) 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Install HANA with SAP Installation Wizard. Verify installation with
# sles4sap/hana_test
# Maintainer: Ricardo Branco <rbranco@suse.de>

use base 'sles4sap';
use strict;
use warnings;
use testapi;
use utils qw(type_string_slow zypper_call);
use Utils::Backends 'use_ssh_serial_console';
use version_utils 'is_sle';
use x11utils 'turn_off_gnome_screensaver';

sub get_total_mem {
    return get_required_var('QEMURAM') if (check_var('BACKEND', 'qemu'));
    my $mem = script_output q@grep ^MemTotal /proc/meminfo | awk '{print $2}'@;
    $mem /= 1024;
    return $mem;
}

sub try_reclaiming_space {
    my $output = script_output q@parted /dev/sda print free | awk '/Free Space/ {print $3}' | tail -1@;
    $output =~ m/([0-9\.]+)([A-Z])B/i;
    my $free  = $1;
    my $units = uc($2);
    if ($units eq 'T') {
        $free *= 1024;
    }
    elsif ($units ne 'G') {
        # Assume there's no space available if units are not T or G
        $free = 0;
    }
    # Only attempt to reclaim space from /dev/system/root if there's not enough free space available
    return if ($free >= 70);

    $output = script_output 'df -h --output=size,used,avail / | tail -1';
    my ($root_size, $root_used, $root_free) = split(/\s+/, $output);
    $root_size =~ s/([A-Z])$//i;
    $root_free =~ s/([A-Z])$//i;
    $units = $1;
    if ($units eq 'T') {
        $root_free *= 1024;
    }
    elsif ($units ne 'G') {
        # Asume there's not enough free space on /dev/system/root if units are not T or G
        $root_free = 0;
    }
    # Always leave at least 25Gb free on /dev/system/root for packages and Hana
    $root_free -= 25;
    $root_size -= $root_free if ($root_free > 0);
    if ($root_size >= ($root_used + 25)) {
        assert_script_run "btrfs filesystem resize $root_size$units /";
        assert_script_run "lvreduce --yes --force --size $root_size$units /dev/system/root";
    }
    $output = script_output q@pvscan | sed -n '/system/s/\[//p' | awk '(NSIZE=$6-$9+1) {print $2","NSIZE","$10}'@;
    my ($device, $newsize, $unit) = split(/,/, $output);
    $unit = substr($unit, 0, 1);
    # Do nothing else unless there's at least 1GB to reclaim in the LVM partition
    return unless ($unit eq 'G' or $unit eq 'T');
    assert_script_run "pvresize -y --setphysicalvolumesize $newsize$unit $device";
    $device =~ s/([0-9]+)$//;
    my $partnum = $1;
    $newsize += 5;    # Just to be sure that the partition is bigger than the PV
    assert_script_run "parted -s $device resizepart $partnum $newsize$unit";
    type_string "partprobe;sync;sync;\n";
}

sub run {
    my ($self) = @_;
    my ($proto, $path) = split m|://|, get_required_var('MEDIA');
    die "Currently supported protocols are nfs and smb" unless $proto =~ /^(nfs|smb)$/;

    my $sid      = get_required_var('INSTANCE_SID');
    my $password = 'Qwerty_123';
    set_var('PASSWORD', $password);

    check_var('BACKEND', 'ipmi') ? use_ssh_serial_console : select_console 'root-console';
    my $RAM = get_total_mem();
    die "RAM=$RAM. The SUT needs at least 32G of RAM" if $RAM < 32000;

    # If on IPMI, let's try to reclaim some of the space from the system PV which may be needed for Hana
    try_reclaiming_space if (check_var('BACKEND', 'ipmi'));

    # Add host's IP to /etc/hosts
    my $netdevice = get_var('SUT_NETDEVICE', 'eth0');
    assert_script_run "echo \$(ip -4 addr show dev $netdevice | sed -rne '/inet/s/[[:blank:]]*inet ([0-9\\.]*).*/\\1/p') \$(hostname) >> /etc/hosts";
    if (is_sle('>=15')) {
        my $arch       = get_required_var('ARCH');
        my $os_version = script_output('sed -rn "s/^VERSION_ID=\"(.*)\"/\1/p" /etc/os-release');
        assert_script_run "SUSEConnect -p sle-module-legacy/$os_version/$arch";
        zypper_call('in libopenssl1_0_0');
    }
    select_console 'x11';
    # Hide the mouse so no needle will fail because of the mouse pointer appearing
    mouse_hide;

    x11_start_program('xterm');
    turn_off_gnome_screensaver;
    type_string "killall xterm\n";
    assert_screen 'generic-desktop';
    x11_start_program('yast2 sap-installation-wizard', target_match => 'sap-installation-wizard');
    send_key 'tab';
    send_key_until_needlematch 'sap-wizard-proto-' . $proto . '-selected', 'down';
    send_key 'alt-p';
    type_string_slow "$path", wait_still_screen => 1;
    send_key 'tab';
    send_key $cmd{next};
    assert_screen 'sap-wizard-copying-media',     120;
    assert_screen 'sap-wizard-supplement-medium', 4000;
    send_key $cmd{next};
    assert_screen 'sap-wizard-additional-repos';
    send_key $cmd{next};
    assert_screen 'sap-wizard-hana-system-parameters';
    # SAP SID / Password
    send_key 'alt-s';
    type_string $sid;
    wait_screen_change { send_key 'alt-a' };
    type_password $password;
    wait_screen_change { send_key 'tab' };
    type_password $password;
    wait_screen_change { send_key $cmd{ok} };
    assert_screen 'sap-wizard-performing-installation', 60;
    assert_screen 'sap-wizard-profile-ready',           300;
    send_key $cmd{next};
    if (check_screen('sap-wizard-disk-selection', 60)) {
        # Install in sda
        assert_and_click 'sap-wizard-disk-selection';
        send_key 'alt-o';
    }
    send_key 'alt-o' if (check_screen 'sap-wizard-partition-issues',      60);
    send_key 'alt-y' if (check_screen 'sap-wizard-continue-installation', 30);
    assert_screen 'sap-product-installation';
    assert_screen [qw(sap-wizard-installation-summary sap-wizard-finished sap-wizard-failed sap-wizard-error)], 4000;
    send_key $cmd{ok};
    if (match_has_tag 'sap-wizard-installation-summary') {
        assert_screen 'generic-desktop', 600;
    } else {
        # Wait for SAP wizard to finish writing logs
        check_screen 'generic-desktop', 90;
        die "Failed";
    }
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    check_var('BACKEND', 'ipmi') ? use_ssh_serial_console : select_console 'root-console';
    assert_script_run 'tar cf /tmp/logs.tar /var/adm/autoinstall/logs; xz -9v /tmp/logs.tar';
    upload_logs '/tmp/logs.tar.xz';
    assert_script_run "save_y2logs /tmp/y2logs.tar.xz";
    upload_logs "/tmp/y2logs.tar.xz";
    $self->SUPER::post_fail_hook;
}

1;
