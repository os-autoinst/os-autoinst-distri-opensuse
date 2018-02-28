# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package partition_setup;

use base Exporter;
use Exporter;

use strict;
use testapi;
use version_utils 'is_storage_ng';
use installation_user_settings 'await_password_check';

our @EXPORT = qw(create_new_partition_table addpart addlv unselect_xen_pv_cdrom enable_encryption_guided_setup);

my %role = qw(
  OS alt-o
  data alt-d
  swap alt-s
  efi alt-e
  raw alt-a
);

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
    send_key match_has_tag('bsc#1054478') ? 'alt-x' : $cmd{expertpartitioner};
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
    send_key((is_storage_ng) ? 'alt-e' : 'alt-x');    # expert menu
    send_key 'down';
    wait_still_screen 2;
    save_screenshot;
    send_key 'ret';
    # create new partition table, change gpt table if it's available
    # storage-ng always allows partition table selection
    if (!get_var('UEFI') && !check_var('BACKEND', 's390x') || is_storage_ng) {
        assert_screen "create-new-partition-table";
        send_key $table_type_hotkey{$table_type};
        assert_screen "partition-table-$table_type-selected";
        send_key((is_storage_ng) ? $cmd{next} : $cmd{ok});    # OK
    }
    assert_screen 'partition-create-new-table';
    send_key 'alt-y';
}

sub mount_device {
    my ($mount) = shift;
    send_key 'alt-o' if is_storage_ng;
    wait_still_screen 1;
    send_key 'alt-m';
    type_string "$mount";
}

sub addpart {
    my (%args) = @_;
    assert_screen 'expert-partitioner';
    send_key $cmd{addpart};
    # partitioning type does not appear when GPT disk used, GPT is default for UEFI
    # also doesn't appear with storage-ng, as GPT is by default there
    if (is_storage_ng && check_screen 'partition-size', 0) {
        record_soft_failure 'bsc#1055743';
    }
    unless (get_var('UEFI') || check_var('BACKEND', 's390x') || is_storage_ng) {
        assert_screen 'partitioning-type';
        send_key $cmd{next};
    }
    assert_screen 'partition-size';
    if ($args{size}) {
        if (is_storage_ng) {
            # maximum size is selected by default
            send_key 'alt-c';
            assert_screen 'partition-custom-size-selected';
            send_key 'alt-s';
        }
        for (1 .. 10) {
            send_key 'backspace';
        }
        type_string $args{size} . 'mb';
    }
    send_key $cmd{next};
    assert_screen 'partition-role';
    send_key $role{$args{role}};
    send_key $cmd{next};
    assert_screen 'partition-format';
    if ($args{format}) {
        if ($args{format} eq 'donotformat') {
            send_key $cmd{donotformat};
            send_key 'alt-u';
        }
        else {
            send_key 'alt-a' if is_storage_ng;    # Select to format partition, not selected by default
            wait_still_screen 1;
            send_key((is_storage_ng) ? 'alt-f' : 'alt-s');
            send_key 'home';                      # start from the top of the list
            send_key_until_needlematch "partition-selected-$args{format}-type", 'down';
        }
    }
    if ($args{fsid}) {                            # $args{fsid} will describe needle tag below
        send_key 'alt-i';                         # select File system ID
        send_key 'home';                          # start from the top of the list
        if ($args{role} eq 'raw' && !check_var('VIDEOMODE', 'text')) {
            record_soft_failure('bsc#1079399 - Combobox is writable');
            for (1 .. 10) { send_key 'up'; }
        }
        send_key_until_needlematch "partition-selected-$args{fsid}-type", 'down';
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
    send_key((is_storage_ng) ? $cmd{next} : $cmd{finish});
}

sub addlv {
    my (%args) = @_;
    send_key $cmd{addpart};
    send_key 'down';
    send_key 'down';
    wait_still_screen 2;
    save_screenshot;
    send_key 'ret';    # create logical volume
    assert_screen 'partition-lv-type';
    type_string $args{name};
    send_key $cmd{next};
    assert_screen 'partition-lv-size';
    if ($args{size}) {    # use default max size if not defined
        send_key 'alt-c';    # custom size
        assert_screen 'partition-custom-size-selected';
        send_key 'alt-s' if is_storage_ng;
        # Remove text
        send_key 'ctrl-a';
        send_key 'backspace';
        type_string $args{size} . 'mb';
    }
    send_key $cmd{next};
    assert_screen 'partition-role';
    send_key $role{$args{role}};    # swap role
    send_key $cmd{next};
    assert_screen 'partition-format';
    # Add mount
    mount_device $args{mount} if $args{mount};
    send_key(is_storage_ng() ? $cmd{next} : $cmd{finish});
}

# On Xen PV "CDROM" is of the same type as a disk block device so YaST
# naturally sees it as a "disk". We have to uncheck the "CDROM".
sub unselect_xen_pv_cdrom {
    if (check_var('VIRSH_VMM_TYPE', 'linux')) {
        assert_screen 'select-hard-disk';
        if (get_var('TEXTMODE')) {
            send_key_until_needlematch 'uncheck-install-medium', 'tab';
            send_key 'spc';
        }
        else {
            assert_and_click 'uncheck-install-medium';
        }
        send_key $cmd{next};
    }
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

1;
# vim: set sw=4 et:
