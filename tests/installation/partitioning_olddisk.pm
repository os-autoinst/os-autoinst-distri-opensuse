# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
#
# Summary:  Install on old disk
# Maintainer: Joyce Na <jna@suse.de>

use strict;
use warnings;
use base "y2logsstep";
use version_utils qw(is_storage_ng is_sle);
use testapi;

sub run() {
    send_key $cmd{expertpartitioner};
    #assert_screen 'expert-partitioner-setup';
    if (is_storage_ng &&  is_sle('15+')) {
        # start with preconfigured partitions
        send_key 'down';
        send_key 'ret';
    }
    assert_screen 'expert-partitioner-setup';
    sleep 3; 
    # Rescan devices
    if (is_storage_ng &&  is_sle('15+')) {
        send_key $cmd{rescandevices};
        assert_screen 'rescan-devices-warning';    # Confirm rescan
        send_key 'alt-y';
    }
    else {
        send_key 'alt-e';
    }
    wait_still_screen;                         # Wait until rescan is done

    # Select device
    my $disk = get_var('SPECIFICDISK');
    send_key 'tab';
    send_key 'tab';
    send_key_until_needlematch("expert-partitioner-$disk","down",20,2);
    send_key 'ret';
    
    # Edit device 
    send_key 'alt-e';
    assert_screen 'expert-partitioner-sda-edit';
   
    # Format partition with brtfs file system
    send_key 'alt-a';
    assert_screen 'expert-partitioner-format';
    send_key 'ret';
    if (is_storage_ng &&  is_sle('15+')) {
        send_key 'alt-f';
    }
    else {
        send_key 'alt-s';
    }
    send_key_until_needlematch("expert-partitioner-brtfs","up",20,1);
    send_key 'ret';

    # Set mount point and volume label
    send_key 'alt-o';
    send_key 'alt-m';
    for (1 .. 5) { send_key "backspace" }
    send_key '/';
    assert_screen 'expert-partitioner-mount';
    if (is_storage_ng &&  is_sle('15+')) {
        send_key 'alt-s';
    }
    else {
        send_key 'alt-t';
    }
    assert_screen 'fstab-options';
    send_key 'alt-m';
    for (1 .. 45) { send_key "backspace" }
    type_string get_var('PERF_BUILD');
    assert_screen 'volume_label';
    send_key 'alt-o';

    # Expert partition finish
    if (is_storage_ng &&  is_sle('15+')) {
        send_key 'alt-n';
    }
    else {
        send_key 'alt-f';
    }
    assert_screen 'expert-partitioner-finish';
    send_key 'alt-a';

}

1;
