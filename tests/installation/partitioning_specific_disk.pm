# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
#
# Summary:  Install build on specified parition and format this partition
# Maintainer: Joyce Na <jna@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use version_utils qw(is_storage_ng is_sle);
use partition_setup 'mount_device';
use testapi;

# Rescan devices
sub rescan_devices {
    if (is_storage_ng) {
        send_key $cmd{rescandevices};
        assert_screen 'rescan-devices-warning';    # Confirm rescan
        send_key 'alt-y';
    }
    else {
        send_key 'alt-e';
    }
    wait_still_screen;    # Wait until rescan is done
}

# Select partition
sub select_partition {
    my $partition_needle_name = shift;
    send_key 'tab';
    wait_still_screen 3;
    save_screenshot;
    send_key 'tab';
    wait_still_screen 3;
    save_screenshot;
    send_key 'tab';
    wait_still_screen 3;
    save_screenshot;
    for (1 ... 100) {
        send_key 'down';
        send_key_until_needlematch("expert-partitioner-label", "right", 51, 1);
        if (check_screen $partition_needle_name, 2) {
            last;
        }
    }
}

# Format partition with a file system
sub format_partition {
    my $filesystem = get_required_var('PARTITION_FILE_SYSTEM');
    send_key 'alt-a';
    wait_still_screen 3;
    send_key 'ret';
    send_key(is_storage_ng() ? 'alt-f' : 'alt-s');
    send_key_until_needlematch("expert-partitioner-$filesystem", "down", 21, 1);
    send_key 'ret';
}

sub run {
    send_key $cmd{expertpartitioner};
    if (is_storage_ng) {
        # start with preconfigured partitions
        send_key 'down';
        send_key 'ret';
    }
    assert_screen 'expert-partitioner-setup';
    wait_still_screen 3;


    # Select device
    # set swap for vt
    if (get_var("MITIGATION_INSTALL")) {
        select_partition "expert-partitioner-swap";
        send_key 'alt-e';
        save_screenshot;
        wait_still_screen 3;
        send_key 'alt-a';
        save_screenshot;
        send_key $cmd{next};
        save_screenshot;
    }
    wait_still_screen 3;
    my $disk = get_required_var('SPECIFIC_DISK');
    select_partition "expert-partitioner-$disk";

    # Edit device
    send_key 'alt-e';

    assert_screen([qw(partition-role expert-partitioner-format)]);
    if (match_has_tag('partition-role')) {
        send_key 'alt-o';
        send_key $cmd{next};
    }

    wait_still_screen 3;

    format_partition;

    # Set mount point and volume label
    mount_device '/';

    # Expert partition finish
    send_key(is_storage_ng() ? 'alt-n' : 'alt-f');
    send_key 'alt-p';
    wait_still_screen 3;
    if (check_screen("expert-partitioner-Warning_popup", 5)) {
        send_key 'alt-y';
    }
}

1;
