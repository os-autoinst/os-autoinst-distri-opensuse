# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Simple LVM partition validation
# Maintainer: Yiannis Bonatakis <ybonatakis@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use utils;
use y2_module_basetest 'workaround_suppress_lvm_warnings';
use Test::Assert ':all';
use version_utils 'is_storage_ng';
use Utils::Architectures qw(is_aarch64 is_s390x);
use Mojo::JSON 'decode_json';

# pass all block devices from json lsblk output
sub extract_drives {
    my $bd = shift;
    (ref($bd) eq 'HASH' and ref($bd->{blockdevices}) eq 'ARRAY') ?
      return $bd->{blockdevices} : die "Block devices not found among json data";
}

sub _get_children {
    my $drive = shift;
    return (
        (ref($drive) eq 'HASH') and
          defined($drive->{children})) ? $drive->{children} : undef;
}

sub extract_partitions_from_disk {
    my $block_devices = shift;
    return unless (grep($_->{type} eq 'disk', @{$block_devices}));
    my @parts;
    # create list of partitions
    foreach my $drive (@{$block_devices}) {
        push(@parts, grep { $_->{type} eq 'part' } @{_get_children($drive)});
    }
    return \@parts;
}

# container is created on top of a partition
# container is always type crypt and without a mountpoint
sub get_crypt_containers {
    my $partitions = shift;
    my @crypt_containers;
    foreach my $part (@{$partitions}) {
        push(@crypt_containers, grep { $_->{type} eq 'crypt' } @{_get_children($part)})
          if (!defined $part->{mountpoint} and (ref(_get_children($part)) eq 'ARRAY'));
    }
    return \@crypt_containers;
}

sub get_encrypted_volumes {
    my $containers = shift;
    return unless (grep($_->{type} eq 'crypt', @{$containers}));
    my @volumes;
    foreach my $crypt (@{$containers}) {
        push(@volumes, @{_get_children($crypt)});
    }
    return \@volumes;
}

sub cryptsetup_test {
    my $containers = shift;
    my $bkp_file   = '/root/bkp_luks_header';

    die "No /etc/crypttab found!\n" if (script_run('test -f /etc/crypttab'));
    my @crypttab = script_output q[cat /etc/crypttab | awk '{print $1}'];

    foreach (@crypttab) {
        assert_script_run qq[cryptsetup status $_ | grep "is active"];
    }
    record_info('crypttab', @crypttab);

    foreach (@{$containers}) {
        unless (script_output('cryptsetup -v status ' . $_->{name}) =~ m/device:\s+(?<crypt_partition>\/.*\b)/) {
            die "$_->{name} is not active!\n";
        }
        next if (script_run('cryptsetup -v isLuks ' . $+{crypt_partition}) != 0);
        assert_script_run('cryptsetup -v luksUUID ' . $+{crypt_partition});
        assert_script_run('cryptsetup -v luksDump ' . $+{crypt_partition});
        assert_script_run('cryptsetup -v luksHeaderBackup ' . $+{crypt_partition} . ' --header-backup-file ' . $bkp_file);
        validate_script_output("file $bkp_file", sub { m/\bLUKS\sencrypted\sfile\b/ });
        assert_script_run('cryptsetup -v --batch-mode luksHeaderRestore ' . $+{crypt_partition} . ' --header-backup-file ' . $bkp_file);
    }
}

sub run {
    my $self              = shift;
    my $expected_lv_stats = {
        write_access => qr/\s{2}LV Write Access \s+ read\/write/,
        status       => qr/\s{2}LV Status \s+ available/,
        readahead    => qr/\s{2}Read ahead sectors \s+ auto/,
        testactive   => qr/\s{2}# open \s+ [12]/,
        # 254 as major no. points to dev-mapper, see /proc/devices
        block_device => qr/\s{2}Block device \s+ 254:\d/
    };

    $self->select_serial_terminal;
    workaround_suppress_lvm_warnings;

    record_info('INFO', 'Validate LVM config');
    assert_script_run "lvmconfig --mergedconfig --validate | grep \"LVM configuration valid.\"";

    record_info('INFO', 'Validate setup');
    assert_script_run 'lvmdiskscan -v';

    my @active_vols = split(/\n/, script_output q[lvscan | awk '{print $1}']);
    foreach my $vol_status (@active_vols) {
        assert_equals($vol_status, 'ACTIVE', "Volume is Inactive");
    }

    my $pvTotalPE = script_output q[pvdisplay|grep "Total PE" | awk '{print $3}'];
    my $pvFreePE  = script_output q[pvdisplay|grep "Free PE" | awk '{print $3}'];

    assert_script_run 'pvs -a';

    my @volumes = split(/\n/, script_output q[lvscan | awk '{print $2}'| sed s/\'//g]);
    my $lv_size = 0;

    foreach my $volume (@volumes) {
        chomp;
        my $lvdisp_output = script_output "lvdisplay $volume";
        my $val           = script_output qq[lvdisplay $volume|grep \"Current LE\" | awk '{print \$3}'];

        $lv_size += script_output qq[lvdisplay $volume|grep \"Current LE\" | awk '{print \$3}'];

        my $results = '';
        foreach (keys %{$expected_lv_stats}) {
            $results .= "$_ was not found in filesystem\n" unless ($lvdisp_output =~ /(?<tested_string>$expected_lv_stats->{$_})/);
            record_info('TEST', "Found $+{tested_string} in $volume");
        }
        die "Partitions not found in $volume configuration: \n $results" if ($results);
    }

    assert_equals($pvTotalPE - $pvFreePE, $lv_size, "Sum of Logical Extends differs!");

    record_info('INFO', 'Create a file on home volume');
    my $test_file = '/home/bernhard/test_file.txt';
    assert_script_run 'df -h  | tee original_usage';
    assert_script_run "dd if=/dev/zero of=$test_file count=1024 bs=1M";
    assert_script_run "ls -lah $test_file";
    if ((script_run "sync && diff <(cat original_usage) <(df -h)") != 1) {
        die "LVM usage stats do not differ!";
    }

    record_info('LAYOUT', 'Partition layout overview');
    my $drives = extract_drives(decode_json(script_output qq[lsblk -p -o NAME,TYPE,MOUNTPOINT -J -e 11]));
    record_info('DRIVES', 'Total = ' . scalar @{$drives});
    my $parts = extract_partitions_from_disk($drives);
    record_info('PARTS', 'Total = ' . scalar @{$parts});
    my $crypts = get_crypt_containers($parts);
    record_info('CRYPT', 'Total = ' . scalar @{$crypts});
    my $encrypted_volumes = get_encrypted_volumes($crypts);
    record_info('VOLUMES',  'Total = ' . scalar @{$encrypted_volumes});
    record_info($_->{name}, "Mounted in $_->{mountpoint} ($_->{type})") foreach (@{$encrypted_volumes});

    # read kernel boot parameters, determine root partition
    my ($rootfs_part) = grep { /root=[^\s]*/ }
      split(/\s/, script_output qq[cat /proc/cmdline | tee /dev/$serialdev]);
    # possible formats
    # root=UUID=aaf272eb-7817-4e04-9f4d-da4e4e354706
    # root=/dev/mapper/vg+lv
    # root=/dev/sdaX
    die "No rootfs found in /proc/cmdline!\n" unless defined($rootfs_part);
    record_info('rootfs', $rootfs_part = (split(/\=/, $rootfs_part, 2))[1]);

    # get partition which holds initrd, or where does /boot live?
    my $initrd_record = script_output('df -T /boot/initrd-$(uname -a | cut -f 3 -d\' \') | tail -n 1| tee /dev/' . "$serialdev");
    my $boot_part     = (split(/\s/, $initrd_record))[0];
    assert_script_run("df | grep -P \'^$boot_part\'| grep boot");
    record_info('boot', $boot_part);

    ### rootfs != boot
    # a) explicitly separated /boot
    # b) UEFI - old storage stack puts whole /boot on separate partition
    #         - storage-ng separates only /boot/efi
    my $efi_zipl_boot;
    if (get_var('UEFI')) {
        my $efi_zipl_boot = script_output('df -T /boot/efi| tail -n 1| awk \'{print $1}\' |tee /dev/' . "$serialdev");
        record_info('EFI', $efi_zipl_boot);
    } elsif (is_s390x) {
        my $efi_zipl_boot = script_output('df -T /boot/zipl| tail -n 1| awk \'{print $1}\' |tee /dev/' . "$serialdev");
        record_info('ZIPL', $efi_zipl_boot);
    } else {
        bmwqemu::diag("x86_64 and ppc64le don't have any additional boot partition to be mounted");
    }

    # all installations can separate /boot
    if ((get_var('NAME') =~ m/separate/) or
        ((get_var('NAME') =~ m/cryptlvm/) and !is_storage_ng)) {
        assert_not_equals($boot_part, $rootfs_part, 'Dedicated partition for /boot is expected!');
    } else {
        assert_equals($boot_part, $rootfs_part, '/boot is expected to be part of rootfs!');
    }

    # handle special boot partition
    if (get_var('UEFI') || is_aarch64 || is_s390x) {
        assert_not_equals($efi_zipl_boot, $rootfs_part, "/boot/zipl or /boot/efi should be located on a separate partition");
    }

    record_info('CRYPT', 'Test cryptsetup functions');
    cryptsetup_test($crypts);

    record_info('PARTED', 'Partition align-check');
    foreach my $dev (@{$drives}) {
        for (my $i = 1; $i <= scalar @{_get_children($dev)}; $i++) {
            assert_script_run("parted $dev->{name} align-check optimal $i");
        }
    }
    record_info('PARTED', script_output qq[parted -lms]);
}

1;

