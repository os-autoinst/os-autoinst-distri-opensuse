=head1 y2snapper_common.pm

Library for creating snapshot by using YaST2 snapper.

=cut
package y2snapper_common;

use strict;
use warnings;
use testapi;
use utils;
use version_utils;

=head2 y2snapper_select_current_conf

 y2snapper_select_current_conf($ncurses);

Select Current Configuration on Snapshots screen
C<$ncurses> is used to check if it is ncurses.

=cut
sub y2snapper_select_current_conf {
    my ($self, $ncurses) = @_;
    $ncurses //= 0;
    if ($ncurses) {
        send_key 'alt-tab';    # Focus Current Configuration selection box
        send_key 'down';       # Expand test configuration selection box
        send_key 'down';       # Select test configuration
        send_key 'ret';        # Apply selection
        send_key 'tab';
    }
    else {
        send_key 'shift-tab';    # Focus Current Configuration selection box
        send_key 'down';         # Select test configuration
    }
}

=head2 y2snapper_adding_new_snapper_conf

 y2snapper_adding_new_snapper_conf();

Setup another snapper config for /test (creating previously a subvolume for it)
It allows to have more control over diffs amongs snapshots.

=cut
sub y2snapper_adding_new_snapper_conf {
    assert_script_run("btrfs subvolume create /test");
    assert_script_run("snapper -c test create-config /test");
}

=head2 y2snapper_create_snapshot

 y2snapper_create_snapshot($name);

Helper to create a snapper snapshot. C<$name> is the name of snapshot.

=cut
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

=head2 y2snapper_new_snapshot

 y2snapper_new_snapshot($ncurses);

Create a new snapshot.

C<$ncurses> is used to check if it is ncurses. In ncurses it needs to focus to snapshots list manually.

=cut
sub y2snapper_new_snapshot {
    my ($self, $ncurses) = @_;
    $ncurses //= 0;

    assert_screen 'yast2_snapper-snapshots', 100;
    $self->y2snapper_select_current_conf($ncurses);
    assert_screen 'yast2_snapper-empty-list';

    # Create a new snapshot
    $self->y2snapper_create_snapshot;
    # Have to focus to Snapshots list manually in ncurses
    if ($ncurses) {
        send_key_until_needlematch 'yast2_snapper-focus-in-snapshots', 'tab';
    }
    # Make sure the snapshot is listed in the main window
    send_key_until_needlematch([qw(yast2_snapper-new_snapshot yast2_snapper-new_snapshot_selected)], 'pgdn');
    wait_still_screen 10;
    # C'l'ose the snapper module
    send_key "alt-l";
}

=head2 y2snapper_apply_filesystem_changes

 y2snapper_apply_filesystem_changes();

Performs any modification in filesystem and at least include some change
under /test, which is the subvolume for testing.

=cut
sub y2snapper_apply_filesystem_changes {
    assert_script_run('echo "hello world in snapper conf /root" > /hello_root.txt');
    assert_script_run('echo "hello world in snapper conf /test" > /test/hello_test.txt');
}

=head2 y2snapper_show_changes_and_delete

 y2snapper_show_changes_and_delete($ncurses);

Show changes of snapshot and delete it.

Use C<$ncurses> to check if it is ncurses. Select in ncurses the first subvolume (root) in the tree and expand it.

=cut
sub y2snapper_show_changes_and_delete {
    my ($self, $ncurses) = @_;
    $ncurses //= 0;

    assert_screen 'yast2_snapper-snapshots', 100;
    $self->y2snapper_select_current_conf($ncurses);

    assert_screen 'yast2_snapper-new_snapshot_selected';
    # Press Show Changes
    send_key "alt-s";
    assert_screen 'yast2_snapper-unselected_testdata';
    if ($ncurses) {
        # Select 1. subvolume (root) in the tree and expand it
        wait_screen_change { send_key "ret" };
        wait_screen_change { send_key "end" };
    }
    else {
        wait_screen_change { send_key "tab" };
        wait_screen_change { send_key "spc" };
    }
    assert_screen 'yast2_snapper-selected_testdata';
    # Close the dialog and make sure it is closed
    send_key 'alt-c';
    # Dele't'e the snapshot
    send_key "alt-t";
    assert_screen 'yast2_snapper-confirm_delete';
    send_key "alt-y";
}

=head2 y2snapper_clean_and_quit

 y2snapper_clean_and_quit($module_name);

C<$module_name> is YaST2 module yast2-snapper.
Quit yast2-snapper and clean up the test data.

=cut
sub y2snapper_clean_and_quit {
    my ($self, $module_name) = @_;

    # After deletion of snapshot sometimes the UI gets busy, delete button is even disabled
    # but the UI is unresponsive for a time
    wait_still_screen 10;
    # C'l'ose the snapper module
    wait_screen_change { send_key "alt-l"; };

    if (defined($module_name)) {
        wait_serial("$module_name-0", 240) || die "yast2 snapper failed";
    }
    else {
        # Wait until root gnome terminal is focussed, delete the directory and close window
        assert_screen('root-gnome-terminal', timeout => 180);
    }

    script_run 'rm /hello_root.txt';
    script_run 'snapper -c test delete-config';
    script_run 'rm -rf /test/*';
    script_run "ls";
    unless (defined($module_name)) {
        type_string "exit\n";
        save_screenshot;
        type_string "exit\n";
    }
}

=head2 y2snapper_failure_analysis

 y2snapper_failure_analysis();

Analyse failure and upload logs.

=cut
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
