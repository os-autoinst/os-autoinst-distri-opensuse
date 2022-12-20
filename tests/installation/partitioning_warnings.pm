# SUSE's openQA tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Create small root partition to test 'too small filesystem for snapshots' warning
#          missing swap warning and on UEFI missing /boot/efi partition
#          https://progress.opensuse.org/issues/16570 https://fate.suse.com/320416
#          Warnings:
#                       1) no /
#                       2) no boot (sle15+)
#                       3) boot with minimal size and correct ID (sle15+)
#                       4) size of / with enabled snapshots
#                       5) size of / non-btrfs (sle15+)
#                       6) no swap (sle12)
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use Utils::Architectures;
use partition_setup qw(create_new_partition_table addpart addboot);
use version_utils qw(is_opensuse is_storage_ng);

sub process_warning {
    my (%args) = @_;
    assert_screen 'partition-warning-' . $args{warning};
    $args{key} //= 'alt-y';    # By default press yes, to accept the settings
    wait_screen_change { send_key $args{key} };
}

sub process_missing_special_partitions {
    # Have missing boot/zipl partition warning only in storage_ng
    if (is_storage_ng && is_s390x) {    # s390x needs /boot/zipl on ext partition
        process_warning(warning => 'no-boot-zipl', key => 'alt-n');
    }
    elsif (is_ppc64le) {    # ppc64le needs PReP /boot
        process_warning(warning => 'no-prep-boot', key => 'alt-n');
    }
    elsif (get_var('UEFI')) {
        process_warning(warning => 'no-efi-boot', key => 'alt-n');
    }
    elsif (is_storage_ng() && is_x86_64) {
        # Storage-ng has GPT by default, so warn about missing bios-boot partition for legacy boot, which is only on x86_64
        process_warning(warning => 'no-bios-boot', key => 'alt-n');
    }
}

sub remove_partition {
    my $remove_key = (is_storage_ng) ? 'alt-e' : 'alt-t';
    wait_screen_change { send_key($remove_key) };
    assert_screen 'remove-partition';
    send_key 'alt-y';
}

sub run {
    # Boot partition limits for storage-ng:
    #      1) ppc  -> >=   2 MiB & ID prep
    #      2) bios -> >=   2 MiB & ID bios_boot
    #      3) uefi -> >= 256 MiB & vfat & /boot/efi
    #      4) zipl -> >= 100 MiB & ext?,xfs & /boot/zipl
    my %roles = (
        ofw => {
            role => 'raw',
            size => 1,
            fsid => 'PReP'
        },
        uefi => {
            role => 'efi',
            size => 100,
            mount => '/boot/efi'
        },
        bios => {
            role => 'raw',
            size => 1,
            fsid => 'bios-boot'
        },
        zipl => {
            role => 'OS',
            size => 50,
            format => 'ext2',
            mount => '/boot/zipl'
        });

    create_new_partition_table;
    # Verify missing root partition error is shown
    assert_screen 'expert-partitioner';
    send_key $cmd{accept};
    # Check no root partition warning (has different keys, with storage-ng it's an error)
    record_info('Test: No root', 'Test warning for missing root partition');
    process_warning(warning => 'no-root-partition', key => (is_storage_ng) ? 'alt-o' : 'alt-n');
    if (!is_storage_ng) {
        record_info('Test: No boot', "Missing boot partition for " . get_var('ARCH'));
        process_missing_special_partitions;
        record_info('Test: No swap', 'Missing swap partition');
        process_warning(warning => 'no-swap', key => 'alt-n');
    }
    # create small enough partition to get warning for enabled snapshots
    # on storage-ng snaphots are disabled as per proposal when partition is to small, so enable to check the warning
    addpart(role => 'OS', size => (is_opensuse) ? 9000 : 11000, format => 'btrfs', enable_snapshots => is_storage_ng);

    # In storage-ng we get this warning when adding/editing partition
    if (is_storage_ng) {
        record_info('Test: Snapshots + small root', 'Enable snapshots for undersized root partition');
        process_warning(warning => 'too-small-for-snapshots');
        send_key $cmd{next};
    }

    assert_screen 'expert-partitioner';
    send_key $cmd{accept};
    # Verify warning about missing swap and too small partition size on non storage-ng
    # Warning about small partition is shown later for non storage-ng
    # On power we get warning about missing prepboot before too small partition warning, which is different to arm
    # That is relevant for old storage stack, on s390x we don't get warning about missing boot/zipl
    # Swap warning is not shown in storage-ng as controlled by the checkbox
    if (!is_storage_ng) {
        # No further warnings on x86_64 and s390x on non-storage-ng
        if (get_var('ARCH') =~ /x86_64|s390x/) {
            record_info('Test: Snapshots + small root', 'Enable snapshots for undersized root partition');
            process_warning(warning => 'too-small-for-snapshots');
            record_info('Test: No swap', 'Missing swap partition');
            process_warning(warning => 'no-swap', key => 'alt-n');
        }
        else {
            if (!is_ppc64le) {
                record_info('Test: Snapshots + small root', 'Enable snapshots for undersized root partition');
                process_warning(warning => 'too-small-for-snapshots', key => 'alt-n');
            }
            record_info('Test: No boot', "Missing boot partition for " . get_var('ARCH'));
            process_missing_special_partitions;
            if (is_ppc64le) {
                record_info('Test: Snapshots + small root', 'Enable snapshots for undersized root partition');
                process_warning(warning => 'too-small-for-snapshots', key => 'alt-n');
            }
            record_info('Test: No swap', 'Missing swap partition');
            process_warning(warning => 'no-swap', key => 'alt-n');
        }
    }
    else {
        # in storage-ng need to process only special warnings
        record_info('Test: No boot', "Missing boot partition for " . get_var('ARCH'));
        process_missing_special_partitions;
    }

    if (is_storage_ng) {
        ## Test whether /boot is big enough to contain kernel
        addpart(role => 'OS', size => 40, format => 'ext2', mount => '/boot');
        record_info('Test: /boot space', "Boot partition size is insufficient to fit kernel");
        send_key $cmd{accept};
        process_warning(warning => 'no-space-for-kernel', key => 'alt-o');
        remove_partition;

        ## Add boot partition ID with under limit boot partition size
        foreach (keys %roles) {
            addpart(role => $roles{$_}{role}, size => $roles{$_}{size}, format => $roles{$_}{format}, mount => $roles{$_}{mount}, fsid => $roles{$_}{fsid});
            assert_screen 'expert-partitioner';
            send_key $cmd{accept};
            record_info("Test: $_", "Wrong partition ID or boot partition is too small");
            process_missing_special_partitions;
            send_key 'end';
            remove_partition;
        }

        ## Clean up previously added root
        remove_partition;
        ## Add proper boot partition, so we can see other warnings clearly
        addboot;
        ## Rootfs should be >= than 3 GiB
        addpart(role => 'OS', size => 2000, format => 'xfs');
        send_key $cmd{accept};
        record_info('Test: rootfs', "Root partition without snapshots is too small");
        process_warning(warning => 'too-small-root', key => 'alt-n');

        ## Clean up small root
        remove_partition;
    }
    else {
        ## Clean up previous root
        remove_partition;
        addboot if (get_var('UEFI') || get_var('OFW'));
        addpart(role => 'swap', size => 500);
    }

    addpart(role => 'OS', size => 13000, format => 'btrfs');
    assert_screen 'expert-partitioner';
    save_screenshot;
    send_key $cmd{accept};
}

1;
