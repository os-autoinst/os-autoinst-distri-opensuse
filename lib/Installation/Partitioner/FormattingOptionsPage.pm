# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Formatting Options
# Page of Expert Partitioner Wizard, that are common for all the versions of the
# page (e.g. for both Libstorage and Libstorage-NG).
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::FormattingOptionsPage;
use strict;
use warnings;
use testapi;
use parent 'Installation::WizardPage';

use constant {
    FORMATTING_OPTIONS_PAGE => 'partition-format',
    FILESYSTEM_TYPE => 'partitioning_%s-format-selected',
    PARTITION_ID_PREP_BOOT => 'filesystem-prep',
    PARTITION_ID_EFI_SYSTEM => 'partition-selected-efi-type',
    PARTITION_ID_BIOS_BOOT => 'partition-selected-bios-boot-type',
    PARTITION_ID_LINUX_RAID => 'partition-selected-raid-type',
    PARTITION_ID_LINUX_LVM => 'partition-selected-lvm-type',
    ENCRYPT_DEVICE_OPTION_CHECKED => 'partition-encrypt'
};

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        do_not_format_shortcut => $args->{do_not_format_shortcut},
        format_shortcut => $args->{format_shortcut},
        filesystem_shortcut => $args->{filesystem_shortcut},
        do_not_mount_shortcut => $args->{do_not_mount_shortcut},
        encrypt_device_shortcut => $args->{encrypt_device_shortcut}
    }, $class;
}

# Formatting Options

sub select_do_not_format_device_radiobutton {
    my ($self) = @_;
    assert_screen(FORMATTING_OPTIONS_PAGE);
    send_key($self->{do_not_format_shortcut});
}

sub select_format_device_radiobutton {
    my ($self, $skip) = @_;
    return if $skip;
    assert_screen(FORMATTING_OPTIONS_PAGE);
    send_key($self->{format_shortcut});
}

sub select_partition_id {
    my ($self, $partition_id) = @_;
    assert_screen(FORMATTING_OPTIONS_PAGE);
    send_key 'alt-i';
    # Getting to the end of the list. As on old storage we have
    # editable combobox, so pressing end or home doesn't work
    send_key 'pgdn' for (1 .. 15);
    my $partition_id_needle;
    if ($partition_id eq 'efi') {
        $partition_id_needle = PARTITION_ID_EFI_SYSTEM;
    }
    elsif ($partition_id eq 'bios-boot') {
        $partition_id_needle = PARTITION_ID_BIOS_BOOT;
    }
    elsif ($partition_id eq 'prep-boot') {
        $partition_id_needle = PARTITION_ID_PREP_BOOT;
    }
    elsif ($partition_id eq 'linux-raid') {
        $partition_id_needle = PARTITION_ID_LINUX_RAID;
    }
    elsif ($partition_id eq 'linux-lvm') {
        $partition_id_needle = PARTITION_ID_LINUX_LVM;
    }
    else {
        die "\"$partition_id\" Partition ID is not known.";
    }
    # poo#35134 Sporadic synchronization failure resulted in incorrect choice of partition type
    # add partition screen was not refreshing fast enough
    send_key_until_needlematch($partition_id_needle, 'up', 21, 5);
}

sub select_filesystem {
    my ($self, $filesystem, $skip) = @_;
    return if $skip;
    assert_screen(FORMATTING_OPTIONS_PAGE);
    send_key($self->{filesystem_shortcut});
    send_key 'end', wait_screen_change => 1;
    send_key_until_needlematch((sprintf FILESYSTEM_TYPE, $filesystem), 'up', 21, 5);
}

# Mounting Options

sub select_mount_device_radiobutton {
    my ($self) = @_;
    assert_screen(FORMATTING_OPTIONS_PAGE);
    send_key('alt-o');
}

sub select_do_not_mount_device_radiobutton {
    my ($self) = @_;
    assert_screen(FORMATTING_OPTIONS_PAGE);
    send_key($self->{do_not_mount_shortcut});
}

sub fill_in_mount_point_field {
    my ($self, $mount_point) = @_;
    assert_screen(FORMATTING_OPTIONS_PAGE);
    send_key('alt-m');
    type_string($mount_point);
    send_key('delete');    # to avoid autocomplete
}

sub check_encrypt_device_checkbox {
    my ($self) = @_;
    send_key($self->{encrypt_device_shortcut});
    assert_screen(ENCRYPT_DEVICE_OPTION_CHECKED);
}

1;
