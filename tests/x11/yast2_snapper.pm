# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test for yast2-snapper
# Maintainer: Richard Brown <rbrown@suse.de>

use base "x11test";
use strict;
use testapi;
use utils;

# Test for basic yast2-snapper functionality. It assumes the data of the
# opensuse distri to be available at /home/$username/data (as granted by
# console_setup.pm)

# Helper for letting y2-snapper to create a snapper snapshot
sub y2snapper_create_snapshot {
    my $self = shift;
    my $name = shift || "Awesome Snapshot";
    # Open the 'C'reate dialog and wait until it is there
    send_key "alt-c";
    assert_screen 'yast2_snapper-createsnapshotdialog', 100;
    # Fill the form and finish by pressing the 'O'k-button
    type_string $name;
    wait_screen_change { send_key "tab" };
    wait_screen_change { send_key "tab" };
    wait_screen_change { send_key "tab" };
    wait_screen_change { send_key "tab" };
    wait_screen_change { send_key "tab" };
    type_string "a=1,b=2";
    save_screenshot;
    send_key "alt-o";
}

# Quit yast2-snapper and cleanup
sub clean_and_quit {
    my ($self) = @_;
    # Ensure yast2-snapper is not busy anymore
    wait_still_screen;
    # C'l'ose the snapper module
    send_key "alt-l";
    # Wait until root gnome terminal is focussed, delete the directory and close window
    my $ret = check_screen('root-gnome-terminal');
    if (!$ret) {
        $self->{mute_post_fail} = 1;
        record_soft_failure 'bsc#1032831';
        $self->failure_analysis();
        assert_screen 'root-gnome-terminal', 90;
    }
    script_run 'rm -rf testdata';
    script_run "ls";
    type_string "exit\n";
    save_screenshot;
    type_string "exit\n";
}

sub run {
    my $self = shift;
    # for not running failure_analysis twice in case we fail inside failure_analysis
    $self->{mute_post_fail} = 0;

    # Make sure yast2-snapper is installed (if not: install it)
    ensure_installed "yast2-snapper";

    # Start an xterm as root
    x11_start_program("xterm");
    assert_screen "xterm";
    become_root;
    script_run "cd";

    # Start the yast2 snapper module and wait until it is started
    type_string "yast2 snapper\n";
    assert_screen 'yast2_snapper-snapshots', 100;
    # ensure the last screenshots are visible
    send_key 'pgdn';
    # Make sure the test snapshot is not there
    die("Unexpected snapshot found")
      if (check_screen([qw(yast2_snapper-new_snapshot yast2_snapper-new_snapshot_selected)], 1));

    # Create a new snapshot
    $self->y2snapper_create_snapshot();
    # Make sure the snapshot is listed in the main window
    send_key_until_needlematch([qw(yast2_snapper-new_snapshot yast2_snapper-new_snapshot_selected)], 'pgdn');
    # C'l'ose  the snapper module
    send_key "alt-l";

    wait_still_screen;
    # Download & untar test files
    assert_script_run "tar -xzf /home/$username/data/yast2_snapper.tgz";

    # Start the yast2 snapper module and wait until it is started
    type_string "yast2 snapper\n";
    assert_screen 'yast2_snapper-snapshots', 100;
    send_key_until_needlematch([qw(yast2_snapper-new_snapshot yast2_snapper-new_snapshot_selected)], 'pgdn');
    wait_screen_change { send_key 'end' };
    send_key_until_needlematch('yast2_snapper-new_snapshot_selected', 'up');
    # Press 'S'how changes button and select both directories that have been
    # extracted from the tarball
    send_key "alt-s";
    assert_screen 'yast2_snapper-collapsed_testdata', 200;
    wait_screen_change { send_key "tab" };
    wait_screen_change { send_key "spc" };
    send_key "down";
    wait_screen_change { send_key "spc" };
    # Make sure it shows the new files from the unpacked tarball
    assert_screen 'yast2_snapper-show_testdata', 100;
    # Close the dialog and make sure it is closed
    send_key "alt-c";
    send_key_until_needlematch([qw(yast2_snapper-new_snapshot yast2_snapper-new_snapshot_selected)], 'pgdn');
    wait_screen_change { send_key 'end' };
    send_key_until_needlematch('yast2_snapper-new_snapshot_selected', 'up');
    # Dele't'e the snapshot
    send_key "alt-t";
    assert_screen 'yast2_snapper-confirm_delete', 100;
    send_key "alt-y";
    # Make sure the snapshot is not longer there
    assert_screen [qw(yast2_snapper-snapshots yast2_snapper-new_snapshot yast2_snapper-new_snapshot_selected)], 100;
    if (match_has_tag('yast2_snapper-new_snapshot') or match_has_tag('yast2_snapper-new_snapshot_selected')) {
        diag 'new snapshot found despite requested for deletion, waiting a bit more';
        # In old versions the test was so slow that the issue has never
        # been seen: Deleting a snapshot on at least SP1 does not happen
        # immediately but takes 1-2 seconds. That's why after deletion
        # it's still there which is detected now in the new faster version
        # of the test. On a second look it should really be gone
        wait_still_screen 30;
        if (check_screen([qw(yast2_snapper-new_snapshot yast2_snapper-new_snapshot_selected)], 0)) {
            die("The snapshot is still visible after trying to delete it and waiting a bit");
        }
    }
    $self->clean_and_quit;
}

sub failure_analysis {
    my ($self) = @_;
    # snapper actions can put the system under quite some load so we want to
    # give some more time, e.g. for login in the consoles
    my $factor = 10;
    my $previous_timeout_scale = get_var('TIMEOUT_SCALE', 1);
    set_var('TIMEOUT_SCALE', $previous_timeout_scale * $factor);
    select_console('root-console', await_console => 0);
    my $additional_sleep_time = 10;
    sleep $additional_sleep_time;

    $self->export_kde_logs;
    $self->export_logs;

    # Upload y2log for analysis if yast2 snapper fails
    assert_script_run "save_y2logs /tmp/y2logs.tar.bz2";
    upload_logs "/tmp/y2logs.tar.bz2";
    save_screenshot;
    diag('check if at least snapper low-level commands still work');
    script_run('snapper ls');
    diag('Collect a backtrace from potentially running snapperd, e.g. for bsc#1032831');
    script_run('pidof snapperd && gdb --batch -q -ex "thread apply all bt" -ex q /usr/sbin/snapperd $(pidof snapperd) |& tee /tmp/snapperd_bt_all.log');
    upload_logs '/tmp/snapperd_bt_all.log';
    set_var('TIMEOUT_SCALE', $previous_timeout_scale);
}

sub post_fail_hook {
    my ($self) = @_;
    return if $self->{mute_post_fail};
    $self->failure_analysis();
}

1;
# vim: set sw=4 et:
