# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Show user defined comments in grub2 menu for snapshots
# Maintainer: Dumitru Gutu <dgutu@suse.com>

use base "x11test";
use strict;
use testapi;
use utils;
use power_action_utils 'power_action';

sub y2snapper_create_snapshot {
    my ($self, $name, $user_data) = @_;
    $name      //= 'grub_comment';
    $user_data //= 'bootloader="Bootloader_Comment"';
    # Open the 'C'reate dialog and wait until it is there
    send_key "alt-c";
    assert_screen 'yast2_snapper-createsnapshotdialog', 100;
    # Fill the form and finish by pressing the 'O'k-button
    type_string $name;
    send_key "alt-u";    # match User data column
    type_string $user_data;
    save_screenshot;
    send_key "alt-o";
    save_screenshot;
}

sub run {
    my $self = shift;
    # Start an xterm as root
    x11_start_program('xterm');
    become_root;
    script_run "cd";

    # Start the yast2 snapper module and wait until it is started
    type_string "yast2 snapper\n";
    assert_screen 'yast2_snapper-snapshots', 100;
    # ensure the last screenshots are visible
    wait_screen_change { send_key 'end' };
    # Make sure the test snapshot is not there
    die("Unexpected snapshot found") if (check_screen([qw(grub_comment)], 0));

    # Create a new snapshot
    $self->y2snapper_create_snapshot();
    # Make sure the snapshot is listed in the main window
    send_key_until_needlematch([qw(grub_comment)], 'pgdn');
    # C'l'ose  the snapper module
    send_key "alt-l";
    $self->{in_wait_boot} = 1;
    power_action('reboot', keepconsole => 1, textmode => 1);
    $self->wait_grub(bootloader_time => 90);
    send_key_until_needlematch("boot-menu-snapshot", 'down', 10, 5);
    send_key 'ret';
    $self->{in_wait_boot} = 0;
    # On slow VMs we press down key before snapshots list is on screen
    wait_screen_change { assert_screen 'boot-menu-snapshots-list' };

    send_key_until_needlematch("snap-bootloader-comment", 'down', 10, 5);
    save_screenshot;
    wait_screen_change { send_key 'ret' };
    # boot into the snapshot
    # do not try to search for the grub menu again as we are already here
    $self->wait_boot(textmode => 1, in_grub => 1);
    # request reboot again to ensure we will end up in the original system
    send_key 'ctrl-alt-delete';
    power_action('reboot', keepconsole => 1, textmode => 1, observe => 1);
    $self->wait_boot;
}

1;
