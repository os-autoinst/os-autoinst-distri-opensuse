# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create small root partition (11GB) to test 'too small filesystem for snapshots' warning
#          missing swap warning and on UEFI missing /boot/efi partition
#          https://progress.opensuse.org/issues/16570 https://fate.suse.com/320416
# Maintainer: Jozef Pupava <jpupava@suse.com>

use strict;
use warnings;
use base 'y2logsstep';
use testapi;
use partition_setup;
use version_utils 'is_storage_ng';

sub process_warning {
    my (%args) = @_;
    assert_screen 'partition-warning-' . $args{warning};
    $args{key} //= 'alt-y';    # By default press yes, to accept the settings
    wait_screen_change { send_key $args{key} };
}

sub process_missing_special_partitions {
    # Have missing boot/zipl partition warning only in storage_ng
    if (is_storage_ng && check_var('ARCH', 's390x')) {    # s390x needs /boot/zipl on ext partition
        process_warning(warning => 'no-boot-zipl', key => 'alt-n');
    }
    elsif (get_var('OFW')) {                              # ppc64le needs PReP /boot
        process_warning(warning => 'no-prep-boot', key => 'alt-n');
    }
    elsif (get_var('UEFI')) {
        process_warning(warning => 'no-efi-boot', key => 'alt-n');
    }
    elsif (is_storage_ng() && check_var('ARCH', 'x86_64')) {
        # Storage-ng has GPT by defaut, so warn about missing bios-boot partition for legacy boot, which is only on x86_64
        process_warning(warning => 'no-bios-boot', key => 'alt-n');
    }
}

sub run {
    create_new_partition_table;
    # Verify missing root partition error is shown
    assert_screen 'expert-partitioner';
    send_key $cmd{accept};
    # Check no root partition warning (has different keys, with storage-ng it's an error)
    process_warning(warning => 'no-root-partition', key => (is_storage_ng) ? 'alt-o' : 'alt-n');
    if (!is_storage_ng) {
        process_missing_special_partitions;
        process_warning(warning => 'no-swap', key => 'alt-n');
    }
    # create small enough partition (11GB) to get warning for enabled snapshots
    # on storage-ng snaphots are disabled as per proposal when partition is to small, so enable to check the warning
    addpart(role => 'OS', size => 11000, format => 'btrfs', enable_snapshots => is_storage_ng);

    # In storage-ng we get this warning when adding/editing partition
    if (is_storage_ng) {
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
            process_warning(warning => 'too-small-for-snapshots');
            process_warning(warning => 'no-swap');
            return;
        }
        else {
            process_warning(warning => 'too-small-for-snapshots', key => 'alt-n') if !check_var('ARCH', 'ppc64le');
            process_missing_special_partitions;
            process_warning(warning => 'too-small-for-snapshots', key => 'alt-n') if check_var('ARCH', 'ppc64le');
            process_warning(warning => 'no-swap', key => 'alt-n');
        }
    }
    else {
        # in storage-ng need to process only special warnings
        process_missing_special_partitions;
    }

    ## Add required partitions as per warnings
    if (check_var('ARCH', 's390x')) {    # s390x need /boot/zipl on ext partition
        addpart(role => 'OS', size => 500, format => 'ext2', mount => '/boot');
    }
    elsif (get_var('OFW')) {             # ppc64le need PReP /boot
        addpart(role => 'raw', size => 8, fsid => 'PReP');
    }
    elsif (get_var('UEFI')) {
        addpart(role => 'efi', size => 256);
    }
    elsif (check_var('ARCH', 'x86_64')) {
        # Storage-ng has GPT by defaut, so need bios-boot partition for legacy boot, which is only on x86_64
        addpart(role => 'raw', fsid => 'bios-boot', size => 2);
    }

    assert_screen 'expert-partitioner';
    send_key $cmd{accept};
    if (!is_storage_ng()) {
        process_warning(warning => 'too-small-for-snapshots');
        process_warning(warning => 'no-swap');
    }
}

1;
