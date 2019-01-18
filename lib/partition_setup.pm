# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package partition_setup;

use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi;
use version_utils ':VERSION';
use installation_user_settings 'await_password_check';

our @EXPORT = qw(
  addboot
  addpart
  addlv
  addvg
  create_new_partition_table
  enable_encryption_guided_setup
  resize_partition
  select_first_hard_disk
  take_first_disk
  is_storage_ng_newui
  %partition_roles
  mount_device
);

our %partition_roles = qw(
  OS alt-o
  data alt-d
  swap alt-s
  efi alt-e
  raw alt-a
);

# We got changes to the storage-ng UI in SLE 15 SP1, Leap 15.1 and TW
sub is_storage_ng_newui {
    return is_storage_ng && (
        is_sle('15-SP1+')
        || (is_opensuse && !is_leap('<15.1'))
        || get_var('STORAGE_NG_NEW_UI')
    );
}

sub wipe_existing_partitions_storage_ng {
    send_key_until_needlematch "expert-partitioner-hard-disks", 'right';
    wait_still_screen 2;
    # Remove partition
    send_key 'alt-d';
    # Confirm in pop-up
    assert_screen "delete-all-partitions-confirm";
    send_key 'alt-t';
    # Verify removed
    send_key_until_needlematch "expert-partitioner-vda", 'right';
    assert_screen 'expert-partitioner-unpartitioned';
}


sub create_new_partition_table {
    my ($table_type) = shift // (is_storage_ng) ? 'GPT' : 'MSDOS';
    my %table_type_hotkey = (
        MSDOS => 'alt-m',
        GPT   => 'alt-g',
    );

    assert_screen('release-notes-button');
    send_key $cmd{expertpartitioner};
    if (is_storage_ng) {
        # start with existing configuration
        send_key 'down';
        send_key 'ret';
    }
    assert_screen 'expert-partitioner';
    wait_still_screen;
    #Use storage ng
    send_key_until_needlematch "expert-partitioner-vda", 'right';

    # empty disk partitions by creating new partition table
    # in sle15sp1 is called Pa{r}tition Table
    my $expert_menu_key = (is_storage_ng) ? ((is_storage_ng_newui) ? 'alt-r' : 'alt-e') : 'alt-x';    # expert menu keys

    if (is_storage_ng_newui) {
        # partition table management has been moved from Partitions tab to Overview
        send_key 'alt-o';
        assert_screen 'expert-partitioner-overview';
    }

    # enter Partition table menu
    wait_screen_change { send_key $expert_menu_key };
    send_key 'down';
    wait_still_screen 2;
    save_screenshot;
    send_key 'ret';

    if (is_storage_ng_newui) {
        assert_screen 'expert-partitioner-confirm-dev-removal';
        send_key 'alt-y';
    }

    # create new partition table, change gpt table if it's available
    # storage-ng always allows partition table selection
    if (!get_var('UEFI') && !check_var('BACKEND', 's390x') || is_storage_ng) {
        assert_screen "create-new-partition-table";
        send_key $table_type_hotkey{$table_type};
        assert_screen "partition-table-$table_type-selected";
        send_key((is_storage_ng) ? $cmd{next} : $cmd{ok});    # OK
        send_key 'alt-p' if (is_storage_ng);                  # return back to Partitions tab
    }
    unless (is_storage_ng_newui) {
        assert_screen 'partition-create-new-table';
        send_key 'alt-y';
    }
}

# Set mount point and volume label
sub mount_device {
    my ($mount) = shift;
    send_key 'alt-o' if is_storage_ng;
    wait_still_screen 1;
    send_key 'alt-m';
    for (1 .. 10) { send_key "backspace" }
    type_string "$mount";
    wait_still_screen 1;
    if (get_var('SETUP_VOLUME_LABEL')) {
        send_key((is_storage_ng) ? 'alt-s' : 'alt-t');
        wait_still_screen 1;
        send_key 'alt-m';
        for (1 .. 45) { send_key "backspace" }
        type_string get_var('SETUP_VOLUME_LABEL');
        wait_still_screen 1;
        send_key 'alt-o';
    }
}

# Set size when adding or resizing partition
sub set_partition_size {
    my (%args) = @_;
    assert_screen 'partition-size';
    # Return if do not want to change size
    return unless $args{size};
    if (is_storage_ng) {
        # maximum size is selected by default
        send_key $cmd{customsize};
        assert_screen 'partition-custom-size-selected';
        send_key 'alt-s';
    }
    for (1 .. 10) {
        send_key 'backspace';
    }
    type_string $args{size} . 'mb';
}

# Method assumes that correct disk is already selected
# Sleect Maximum size by default
sub resize_partition {
    my (%args) = @_;
    if (is_storage_ng_newui) {
        send_key 'alt-m';
        # start with preconfigured partitions
        send_key_until_needlematch 'modify-partition-resize', 'down', 5, 3;
        send_key 'ret';
    }
    else {
        send_key $cmd{resize};
    }
    # Set maximum size for the partition
    set_partition_size;
    assert_screen 'partition-maximum-size-selected';
    send_key((is_storage_ng) ? "$cmd{next}" : "$cmd{ok}");
}

sub addpart {
    my (%args) = @_;
    assert_screen 'expert-partitioner';
    send_key $cmd{addpart};
    unless (get_var('UEFI') || check_var('BACKEND', 's390x') || is_storage_ng) {
        assert_screen 'partitioning-type';
        send_key $cmd{next};
    }
    set_partition_size(size => $args{size});
    send_key $cmd{next};
    assert_screen 'partition-role';
    send_key $partition_roles{$args{role}};
    send_key $cmd{next};
    assert_screen 'partition-format';
    if ($args{format}) {
        if ($args{format} eq 'donotformat') {
            send_key $cmd{donotformat};
            send_key 'alt-u';
        }
        else {
            send_key(is_storage_ng() ? 'alt-r' : 'alt-a');    # Select to format partition
            wait_still_screen 1;
            send_key((is_storage_ng) ? 'alt-f' : 'alt-s');
            wait_screen_change { send_key 'home' };           # start from the top of the list
            assert_screen(((is_storage_ng) ? 'partition-selected-ext2-type' : 'partition-selected-btrfs-type'), timeout => 10);
            send_key_until_needlematch "partition-selected-$args{format}-type", 'down', 10, 5;
        }
    }
    # Enable snapshots option works only with btrfs
    if ($args{enable_snapshots} && $args{format} eq 'btrfs') {
        send_key_until_needlematch('partition-btrfs-snapshots-enabled', $cmd{enable_snapshots});
    }
    if ($args{fsid}) {                                        # $args{fsid} will describe needle tag below
        send_key 'alt-i';                                     # select File system ID
        send_key 'home';                                      # start from the top of the list
        if ($args{role} eq 'raw' && !check_var('VIDEOMODE', 'text')) {
            record_soft_failure('bsc#1079399 - Combobox is writable');
            for (1 .. 10) { send_key 'up'; }
        }
        send_key_until_needlematch "partition-selected-$args{fsid}-type", 'down', 10, 5;
    }

    mount_device $args{mount} if $args{mount};

    if ($args{encrypt}) {
        send_key $cmd{encrypt};
        assert_screen 'partition-encrypt';
        send_key $cmd{next};
        assert_screen 'partition-password-prompt';
        send_key 'alt-e';    # select password field
        type_password;
        send_key 'tab';
        type_password;
    }
    send_key(is_storage_ng() ? $cmd{next} : $cmd{finish});
}

sub addvg {
    my (%args) = @_;

    assert_screen 'expert-partitioner';
    send_key $cmd{system_view};
    send_key 'home';
    send_key_until_needlematch('volume_management_feature', 'down');
    wait_still_screen 2;
    send_key(is_storage_ng_newui() ? $cmd{addvg} : $cmd{addpart});
    if (!is_storage_ng_newui) {
        send_key 'down';
        send_key 'ret';
        save_screenshot;
    }
    assert_screen 'partition-add-volume-group';
    send_key 'alt-v';
    type_string $args{name};
    if ($args{add_all_pvs}) {
        send_key 'alt-d';
    }
    else {
        assert_and_click 'partition-select-first-from-top';
        send_key 'alt-a';
    }
    wait_still_screen 2;
    save_screenshot;
    send_key(is_storage_ng() ? $cmd{next} : $cmd{finish});
}

sub addlv {
    my (%args) = @_;

    assert_screen 'expert-partitioner';
    send_key $cmd{system_view};
    send_key 'home';
    send_key_until_needlematch('volume_management_feature', 'down');
    wait_still_screen(stilltime => 3, timeout => 4);
    # Expand collapsed list with VGs
    send_key 'right' if is_sle('<15');
    send_key_until_needlematch 'partition-select-vg-' . "$args{vg}", 'down';
    wait_still_screen(stilltime => 3, timeout => 4);
    # Expand collapsed list with LVs
    send_key 'right' if is_sle('<15');
    send_key 'alt-i' if (is_storage_ng_newui);
    wait_still_screen 2;
    send_key(is_storage_ng_newui() ? $cmd{addlv} : $cmd{addpart});
    if (!is_storage_ng) {
        send_key 'down' for (0 .. 1);
        save_screenshot;
    }
    assert_screen 'partition-lv-type';
    send_key 'alt-g';
    wait_still_screen 2;
    type_string $args{name};
    send_key($args{thinpool} ? 'alt-t' : $args{thinvolume} ? 'alt-i' : 'alt-o');
    send_key $cmd{next};
    assert_screen 'partition-lv-size';

    if ($args{size}) {    # use default max size if not defined
        send_key((is_storage_ng) ? 'alt-t' : $cmd{customsize});    # custom size
        assert_screen 'partition-custom-size-selected';
        send_key 'alt-s' if is_storage_ng;
        # Remove text
        send_key 'ctrl-a';
        send_key 'backspace';
        type_string $args{size} . 'mb';
    }

    send_key $cmd{next};
    return if $args{thinpool};
    assert_screen 'partition-role';
    send_key $partition_roles{$args{role}};                        # swap role
    send_key $cmd{next};
    assert_screen 'partition-format';
    # Add mount
    mount_device $args{mount} if $args{mount};
    send_key(is_storage_ng() ? $cmd{next} : $cmd{finish});
    assert_screen 'expert-partitioner';
}

sub addboot {
    my $part_size          = shift;
    my %default_boot_sizes = (
        ofw        => 8,
        uefi       => 256,
        bios_boot  => 2,
        zipl       => 500,
        unenc_boot => 500
    );

    if (get_var('OFW')) {    # ppc64le always needs PReP boot
        addpart(role => 'raw', size => $part_size // $default_boot_sizes{ofw}, fsid => 'PReP');
    }
    elsif (get_var('UEFI')) {    # UEFI needs partition mounted to /boot/efi for
        addpart(role => 'efi', size => $part_size // $default_boot_sizes{uefi});
    }
    elsif (is_storage_ng && check_var('ARCH', 'x86_64')) {
        # Storage-ng has GPT by defaut, so need bios-boot partition for legacy boot, which is only on x86_64
        addpart(role => 'raw', fsid => 'bios-boot', size => $part_size // $default_boot_sizes{bios_boot});
    }
    elsif (check_var('ARCH', 's390x')) {
        # s390x need /boot/zipl on ext partition
        addpart(role => 'OS', size => $part_size // $default_boot_sizes{zipl}, format => 'ext2', mount => '/boot/zipl');
    }

    if (get_var('UNENCRYPTED_BOOT')) {
        addpart(role => 'OS', size => $part_size // $default_boot_sizes{unenc_boot}, format => 'ext2', mount => '/boot');
    }
}

sub skip_select_first_hard_disk {
    return 1 if match_has_tag 'existing-partitions';    # no selection of hard-disk is required
    if (match_has_tag('select-hard-disks-one-selected')) {    # first hd is already pre-selected
        send_key $cmd{next};
        return 1;
    }
    return 0;
}

sub select_first_hard_disk {
    my @tags           = qw(existing-partitions hard-disk-dev-sdb-selected hard-disk-dev-non-sda-selected select-hard-disks-one-selected);
    my $matched_needle = assert_screen \@tags;
    return if skip_select_first_hard_disk;
    # SUT may have any number disks, only keep the first, unselect all other disks
    # In text mode, the needle has tag 'hard-disk-dev-non-sda-selected' and multiple hotkey_? tags as hints for unselecting
    if (check_var('VIDEOMODE', 'text') && match_has_tag('hard-disk-dev-non-sda-selected')) {
        foreach my $tag (@{$matched_needle->{needle}->{tags}}) {
            if ($tag =~ /hotkey_([a-z])/) {
                send_key 'alt-' . $1;    # Unselect non-first drive
            }
        }
    }
    # Video mode directly matched the sdb-selected needle (old code) or can do the similar (ideal for multiple disks)
    else {
        assert_and_click 'hard-disk-dev-sdb-selected' if match_has_tag('hard-disk-dev-sdb-selected');
        if (match_has_tag('hard-disk-dev-non-sda-selected')) {
            foreach my $tag (grep { $_ =~ /hard-disk-dev-(sd[a-z]|pmem[0-9])/ } @{$matched_needle->{needle}->{tags}}) {
                assert_and_click "$tag-selected";
            }
        }
    }
    assert_screen 'select-hard-disks-one-selected';
    send_key $cmd{next};
}

# Enables encryption in guided setup during installation
sub enable_encryption_guided_setup {
    my $self = shift;
    send_key $cmd{encryptdisk};
    # Bug is only in old storage stack
    if (get_var('ENCRYPT_ACTIVATE_EXISTING') && !is_storage_ng) {
        record_info 'bsc#993247 https://fate.suse.com/321208', 'activated encrypted partition will not be recreated as encrypted';
        return;
    }
    assert_screen 'inst-encrypt-password-prompt';
    type_password;
    send_key 'tab';
    type_password;
    send_key $cmd{next};
    installation_user_settings::await_password_check;
}

sub take_first_disk_storage_ng {
    my (%args) = @_;
    return unless is_storage_ng;
    send_key $cmd{guidedsetup};    # select guided setup
    assert_screen 'select-hard-disks';
    # It's not always the case that SUT has 2 drives, for ipmi it's changing
    # So making it flexible, still assert the screen if want to verify explicitly
    select_first_hard_disk;

    assert_screen [qw(existing-partitions partition-scheme)];
    # If drive(s) is/are not formatted, we have select hard disks page
    if (match_has_tag 'existing-partitions') {
        if (check_var('BACKEND', 'ipmi') && !check_var('VIDEOMODE', 'text')) {
            send_key_until_needlematch("remove-menu", "tab");
            while (check_screen('remove-menu', 3)) {
                send_key 'spc';
                send_key 'down';
                send_key 'ret';
                send_key 'tab';
            }
            save_screenshot;
            send_key $cmd{next};
            if (check_screen([qw(filesystems-options partition-scheme)], 3)) {
                send_key $cmd{next};
            }
            if (check_screen([qw(filesystems-options partition-scheme)], 3)) {
                send_key $cmd{next};
            }
            assert_screen "after-partitioning";
        }
        else {
            send_key $cmd{next};
            assert_screen 'partition-scheme';
        }
    }

    if (!check_var('BACKEND', 'ipmi') || check_var('VIDEOMODE', 'text')) {
        send_key $cmd{next};
        save_screenshot;
        # select btrfs file system
        if (check_var('VIDEOMODE', 'text')) {
            assert_screen 'select-root-filesystem';
            send_key 'alt-f';
            send_key_until_needlematch 'filesystem-btrfs', 'down', 10, 3;
            send_key 'ret';
        }
        else {
            assert_and_click 'default-root-filesystem';
            assert_and_click "filesystem-btrfs";
        }
        assert_screen "btrfs-selected";
        send_key $cmd{next};
    }
}

sub take_first_disk {
    my (%args) = @_;
    # Flow is different for the storage-ng and previous storage stack
    if (is_storage_ng) {
        take_first_disk_storage_ng %args;
    }
    else {
        # create partitioning
        send_key $cmd{createpartsetup};
        assert_screen($args{iscsi} ? 'preparing-disk-select-iscsi-disk' : 'prepare-hard-disk');

        wait_screen_change {
            send_key 'alt-1';
        };
        send_key $cmd{next};

        # with iscsi we may or may not have previous installation on the disk,
        # depending on the scenario we get different screens
        # same can happen with ipmi installations
        assert_screen [qw(use-entire-disk preparing-disk-overview)];
        wait_screen_change { send_key "alt-e" } if match_has_tag 'use-entire-disk';    # use entire disk
        send_key $cmd{next};
    }
}

1;
