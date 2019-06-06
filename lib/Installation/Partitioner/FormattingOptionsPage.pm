# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: TODO
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Installation::Partitioner::FormattingOptionsPage;
use strict;
use warnings;
use testapi;
use parent 'Installation::WizardPage';

use constant {
    FORMATTING_OPTIONS_PAGE => 'partition-format',
    FILESYSTEM_SWAP         => 'partitioning_raid-swap_format-selected',
    FILESYSTEM_FAT          => 'partitioning_raid-fat_format-selected',
    FILESYSTEM_EXT4         => 'partitioning_raid-filesystem_ext4',
    PARTITION_ID_PREP_BOOT  => 'filesystem-prep',
    PARTITION_ID_EFI_SYSTEM => 'partition-selected-efi-type',
    PARTITION_ID_BIOS_BOOT  => 'partition-selected-bios-boot-type',
    PARTITION_ID_LINUX_RAID => 'partition-selected-raid-type'
};



1;
