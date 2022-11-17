# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test module to verify iBFT configuration
# iSCSI Boot Firmware Table (iBFT) is a mechanism for the iSCSI tools to
# extract from the machine NICs the iSCSI connection information so that they
# can automagically mount the iSCSI share/target.  Currently the iSCSI
# information is hard-coded in the initrd. The /sysfs entries are read-only
# one-name-and-value fields.
# Maintainer: Martin Loviska <mloviska@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use Socket;
use testapi;
use Test::Assert 'assert_equals';
use version_utils qw(is_sle);

my $ibft_expected = {
    ethernet => {
        flags => 3,
        prefix_len => 24,
        subnet_mask => '255.255.255.0',
        gateway => '10.0.2.2',
        ip_addr => '10.0.2.15',
        mac => '',
    },
    initiator => {
        initiator_name => 'iqn.2010-04.org.ipxe:00000000-0000-0000-0000-000000000000',
        flags => 3,
    },
    target => {
        target_name => get_required_var('NBF'),
        flags => 3,
        port => 3260,
        chap_type => 0
    },
    acpi_header => {
        oem_table_id => 'iPXE',
        oem_id => 'FENSYS',
        signature => 'iBFT'
    },
    backstore => {
        model => q/'FILEIO|IBLOCK'/,
        vendor => q/'LIO-ORG'/
    }
};

# bit 0: block valid flag should be set
# bit 1: Firmware boot selected flag should be set
sub is_ibft_boot_flag {
    my $received = shift;
    my $mask = oct 0b0000_0011;
    diag("Comparing flag bits...\nGot: $received\nExpected: $mask");
    if (($received & $mask) == 3) {
        return !!1;
    }
    return !!0;
}

sub ibft_validation {
    my $self = shift;
    my @domain = qw(ethernet initiator target acpi_header);
    my $kb_ibft_messsages = q/'iBFT found at|iBFT detected|ibft0: renamed from'/;
    my $ibft_grub = {
        CONFIG_ISCSI_IBFT_FIND => 'y',
        CONFIG_ISCSI_IBFT => 'm'
    };

    # Check if ibft drivers have been loaded
    assert_script_run 'dmesg | grep -E ' . $kb_ibft_messsages;
    # Verify grub entries
    foreach my $entry (keys %{$ibft_grub}) {
        assert_script_run 'grep -r ' . $entry . '=' . $ibft_grub->{$entry} . ' /boot/';
    }
    # Enabling iBFT autoconfiguration for the interfaces should be done in initrd
    if (is_sle('<15-sp4')) {
        assert_script_run 'grep -e rd.iscsi.ibft=1 -e rd.iscsi.firmware=1 /var/log/YaST2/mkinitrd.log';
    } else {
        # In recent products yast2-bootloader calls dracut instead of mkinitrd, so the logs differ
        assert_script_run 'zgrep -e rd.iscsi.ibft=1 -e rd.iscsi.firmware=1 /var/log/YaST2/y2log*';
    }

    # Scan for ibft interface
    assert_script_run 'ip a | grep -i ibft';
    my $ibft_setup = script_output 'for a in `find /sys/firmware/ibft/ -type f -print`; do  echo -n "$a:";  cat $a; echo; done';
    my @config = split(/\n/, $ibft_setup);

    foreach my $ditem (@domain) {
        my %ibft_sysfs = map { chomp; (my $filtered = $_) =~ s/.*\///; $filtered =~ s/-/_/; split(/:/, $filtered, 2) } grep { m/$ditem/ } @config;
        foreach my $dkey (keys %{$ibft_expected->{$ditem}}) {
            if ($dkey eq 'flags') {
                unless (is_ibft_boot_flag($ibft_sysfs{flags})) {
                    record_info('Mismatch', 'Flags bits does not match!', result => 'fail');
                    $self->result('fail');
                }
            }
            else {
                assert_equals($ibft_expected->{$ditem}->{$dkey}, $ibft_sysfs{$dkey},
                    "\nComparing: $ditem->$dkey\nGot: $ibft_sysfs{$dkey}\nExpected: $ibft_expected->{$ditem}->{$dkey}\n");
            }
        }
    }
}

sub run {
    my $self = shift;
    my $reg_tx = qr/txdata_octets:\s+\d+/;
    my $reg_rx = qr/rxdata_octets:\s+\d+/;
    # Requires NICTYPE=user and backend/qemu.pm code to run
    $ibft_expected->{ethernet}->{mac} = get_required_var('NICMAC');

    my $fqdn = testapi::get_required_var('WORKER_HOSTNAME');
    $ibft_expected->{target}->{ip_addr} = inet_ntoa(inet_aton($fqdn));

    select_console 'root-console';
    # find iscsi drive
    my $iscsi_drive = script_output 'lsblk --scsi | grep -i iscsi | awk \'NR==1 {print $1}\'';
    die "No iSCSI drive found!\n" unless ($iscsi_drive);
    assert_script_run 'ls -l /dev/disk/by-path | grep -E -e ' . $iscsi_drive . ' -e ' . $ibft_expected->{target}->{ip_addr} .
      ' -e ' . $ibft_expected->{target}->{target_name};
    assert_script_run 'lsblk -o KNAME,MOUNTPOINT,SIZE,RO,TYPE,VENDOR,TRAN,MODE,HCTL,STATE,MAJ:MIN | grep ' . $iscsi_drive;
    assert_script_run 'lsscsi -cl | grep -E -e state=running -ie ' . $ibft_expected->{backstore}->{vendor} . ' -ie ' . $ibft_expected->{backstore}->{model};
    assert_script_run 'iscsiadm -m session -P 1|grep -e ' . $ibft_expected->{target}->{target_name} . ' -e ' . $ibft_expected->{target}->{ip_addr} .
      ':' . $ibft_expected->{target}->{port} . ' -e ' . $ibft_expected->{initiator}->{initiator_name} . ' -e ' . $ibft_expected->{ethernet}->{ip_addr};

    # Measure TX & RX several times
    my $tx_prev = 0;
    my $rx_prev = 0;
    for (1 .. 5) {
        my $raw_data = script_output 'iscsiadm -m session -s';
        if ($raw_data =~ /(?<record>$reg_tx)/) {
            $+{record} =~ /(?<tx_data>\b\d+\b)/;
            # numify
            my $tx = $+{tx_data} + 0;
            diag "\nPrevious: $tx_prev\nCurrent: $tx\n";
            die "No data has been transmitted since last iteration!\n" if ($tx < $tx_prev);
            $tx_prev = $tx;
        }
        if ($raw_data =~ /(?<record>$reg_rx)/) {
            $+{record} =~ /(?<rx_data>\b\d+\b)/;
            # numify
            my $rx = $+{rx_data} + 0;
            diag "\nPrevious: $rx_prev\nCurrent: $rx\n";
            die "No data has been received since last iteration!\n" if ($rx < $rx_prev);
            $rx_prev = $rx;
        }
        assert_script_run 'dd if=/dev/zero of=/home/bernhard/iscsi_test_file conv=fsync bs=1M count=100';
    }
    for (1 .. 3) {
        assert_script_run 'hdparm -tT /dev/' . $iscsi_drive;
    }
    assert_script_run 'smartctl -i /dev/' . $iscsi_drive;
    assert_script_run 'sg_turs /dev/' . $iscsi_drive . ' -vt -n 10';
    $self->ibft_validation;
}

1;
