package y2snapper_common;

use strict;
use testapi;
use utils;
use version_utils;

# Helper for letting y2-snapper to create a snapper snapshot
sub y2snapper_create_snapshot {
    my $self = shift;
    my $name = shift || "Awesome Snapshot";
    # Open the 'C'reate dialog and wait until it is there
    send_key "alt-c";
    assert_screen 'yast2_snapper-createsnapshotdialog', 100;
    # Fill the form and finish by pressing the 'O'k-button
    type_string $name;
    wait_screen_change { send_key "alt-u" };
    type_string "a=1,b=2";
    save_screenshot;
    send_key "alt-o";
}

sub y2snapper_new_snapshot {
    my ($self, $ncurses) = @_;
    $ncurses //= 0;

    assert_screen 'yast2_snapper-snapshots', 100;
    # ensure the last screenshots are visible
    send_key 'pgdn';
    # Make sure the test snapshot is not there
    die("Unexpected snapshot found")
      if (check_screen([qw(yast2_snapper-new_snapshot yast2_snapper-new_snapshot_selected)], 1));

    # Create a new snapshot
    $self->y2snapper_create_snapshot;
    # Have to focus to Snapshots list manually in ncurses
    if ($ncurses) {
        send_key_until_needlematch 'yast2_snapper-focus-in-snapshots', 'tab';
    }
    # Make sure the snapshot is listed in the main window
    send_key_until_needlematch([qw(yast2_snapper-new_snapshot yast2_snapper-new_snapshot_selected)], 'pgdn');
    # C'l'ose  the snapper module
    send_key "alt-l";
}

sub y2snapper_untar_testfile {
    # Due to the product change for bsc#1085266 /root is not included in
    # snapshots anymore
    my $args = is_sle('<15') || is_leap('<15.0') ? '' : '-C /etc';
    assert_script_run "tar $args -xzf /home/$username/data/yast2_snapper.tgz";
}

sub y2snapper_show_changes_and_delete {
    my ($self, $ncurses) = @_;
    $ncurses //= 0;

    assert_screen 'yast2_snapper-snapshots', 100;
    send_key_until_needlematch([qw(yast2_snapper-new_snapshot yast2_snapper-new_snapshot_selected)], 'pgdn');
    wait_screen_change { send_key 'end' };
    send_key_until_needlematch('yast2_snapper-new_snapshot_selected', 'up');
    # Press 'S'how changes button and select both directories that have been
    # extracted from the tarball
    send_key "alt-s";
    assert_screen 'yast2_snapper-collapsed_testdata', 200;
    if ($ncurses) {
        # Select 1. subvolume (root) in the tree and expand it
        wait_screen_change { send_key "ret" };
        wait_screen_change { send_key "end" };
    }
    else {
        wait_screen_change { send_key "tab" };
        wait_screen_change { send_key "spc" };
    }
    # Make sure it shows the new files from the unpacked tarball
    send_key_until_needlematch 'yast2_snapper-show_testdata', 'up';
    # Close the dialog and make sure it is closed
    send_key 'alt-c';
    # If snapshot list very long cannot show at one page, the 'yast2_snapper-new_snapshot' will never show up
    # Added 'yast2_snapper-snapshots' needle to confirm the 'alt-c' closed the window
    # Refer ticket: https://progress.opensuse.org/issues/45107
    die '"Selected Snapshot Overview" window is not closed after sending alt-c' unless check_screen([qw(yast2_snapper-new_snapshot yast2_snapper-snapshots)], 100);
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
}

# Quit yast2-snapper and cleanup
sub y2snapper_clean_and_quit {
    my ($self, $ncurses) = @_;
    $ncurses //= 0;

    # Ensure yast2-snapper is not busy anymore
    wait_still_screen;
    # C'l'ose the snapper module
    wait_screen_change { send_key "alt-l"; };

    if ($ncurses) {
        wait_serial("yast2-snapper-status-0", 240) || die "yast2 snapper failed";
    }
    else {
        # Wait until root gnome terminal is focussed, delete the directory and close window
        assert_screen('root-gnome-terminal', timeout => 180);
    }

    script_run 'rm -rf testdata';
    script_run "ls";
    if (!$ncurses) {
        type_string "exit\n";
        save_screenshot;
        type_string "exit\n";
    }
}

sub y2snapper_failure_analysis {
    my ($self) = @_;
    # snapper actions can put the system under quite some load so we want to
    # give some more time, e.g. for login in the consoles
    my $factor                 = 30;
    my $previous_timeout_scale = get_var('TIMEOUT_SCALE', 1);
    set_var('TIMEOUT_SCALE', $previous_timeout_scale * $factor);
    select_console('log-console', await_console => 0);
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
    type_string "exit\n";
}

1;
