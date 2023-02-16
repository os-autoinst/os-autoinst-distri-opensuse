# SUSE's openQA tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-snapper grub2
# Summary: Show user defined comments in grub2 menu for snapshots
# - Launch yast2 snapper
# - Create a new snapshot, name "grub_comment", user_data
# "bootloader="Bootloader_Comment""
# - Check main window for the created snapshot
# - Reboot test machine
# - On grub, select "Start bootloader from a read-only snapshot"
# - Select "Bootloader_comment" option
# - Reboot
# - Make sure machine is back to original system
# Maintainer: Dumitru Gutu <dgutu@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use Utils::Backends 'is_remote_backend';
use power_action_utils 'power_action';

sub y2snapper_create_snapshot {
    my ($self, $name, $user_data) = @_;
    $name //= 'grub_comment';
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
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'snapper');
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
    wait_serial("$module_name-0", 200) || die "'yast2 $module_name' didn't finish";
    $self->{in_wait_boot} = 1;
    record_info 'Snapshot created', 'booting the system into created snapshot';
    power_action('reboot', keepconsole => 1);
    $self->wait_grub(bootloader_time => 350);
    send_key_until_needlematch("boot-menu-snapshot", 'down', 11, 5);
    send_key 'ret';
    $self->{in_wait_boot} = 0;
    # On slow VMs we press down key before snapshots list is on screen
    wait_screen_change { assert_screen 'boot-menu-snapshots-list' };

    send_key_until_needlematch("snap-bootloader-comment", 'down', 11, 5);
    save_screenshot;
    wait_screen_change { send_key 'ret' };

    # waitboot is not aware of the DESKTOP variable, ensure it knows
    my $is_textmode = check_var('DESKTOP', 'textmode');
    record_info 'Snapshot found', 'Waiting to boot the system';
    # boot into the snapshot
    # do not try to search for the grub menu again as we are already here
    $self->wait_boot(textmode => $is_textmode, in_grub => 1);
    # request reboot again to ensure we will end up in the original system
    record_info 'Desktop reached', 'Now return system to original state with a reboot';
    power_action('reboot', keepconsole => 1);
    $self->wait_boot(textmode => $is_textmode, in_grub => 1, bootloader_time => 350);
}

1;
