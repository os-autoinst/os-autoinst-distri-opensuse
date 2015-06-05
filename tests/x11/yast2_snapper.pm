use base "x11test";
use testapi;
# Wrap the commands for downloading extra data used in this test.
# Does not care for getting a shell - just types the commands to a shell that
# you have to provide before calling this.
sub download_testdata() {
    my $self = shift;
    type_string "pushd ~\n";
    script_run("curl -L -v " . autoinst_url . "/data > test.data; echo \"curl-\$?\" > /dev/$serialdev");
    wait_serial("curl-0", 10) || die 'curl failed';
    script_run " cpio -id < test.data; echo \"cpio-\$?\"> /dev/$serialdev";
    wait_serial("cpio-0", 10) || die 'cpio failed';
    script_run "ls -al data";
    type_string "popd\n";
    save_screenshot;
}
# Helper for letting y2-snapper to create a snapper snapshot
sub y2snapper_create_snapshot() {
    my $self = shift;
    my $name = shift || "Awesome Snapshot";
   # Open the 'C'reate dialog and wait until it is there
    send_key "alt-c";
    assert_screen 'yast2_snapper-createsnapshotdialog', 100;
    # Fill the form and finish by pressing the 'O'k-button
    type_string $name;
    sleep 2;
    send_key "tab";
    sleep 2;
    send_key "tab";
    sleep 2;
    send_key "tab";
    sleep 2;
    type_string "a=1,b=2";
    sleep 2;
    send_key "alt-o";
}
sub run() {
    my $self = shift;
    # Make sure yast2-snapper is installed (if not: install it)
    ensure_installed "yast2-snapper";
    # Start an xterm as root
    x11_start_program("xterm");
    wait_idle;
    become_root;
    # Create a snapper config
    script_run "btrfs subvolume create /tmp/testdata";
    script_run "snapper create-config /tmp/testdata";
    # Start the yast2 snapper module and wait until it is started
    script_run "yast2 snapper";
    assert_screen 'yast2_snapper-nosnapshots', 100;
    # Create a new snapshot
    $self->y2snapper_create_snapshot();
    # Make sure the snapshot is listed in the main window
    assert_screen 'yast2_snapper-snapshotlisted', 100;
    # C'l'ose  the snapper module
    send_key "alt-l";
    # Download & untar test files
    wait_idle;
    $self->download_testdata();
    script_run "cd /tmp";
    script_run "tar -xzf ~/data/yast2_snapper.tgz";
    wait_idle;
    # Start the yast2 snapper module and wait until it is started
    script_run "yast2 snapper";
    # Make sure the snapper module is started
    assert_screen 'yast2_snapper-snapshotlisted', 100;
    # Press 'S'how changes button and select both directories that have been
    # extracted from the tarball
    send_key "alt-s";
    sleep 2;
    send_key "tab";
    sleep 2;
    send_key "spc";
    sleep 2;
    send_key "down";
    sleep 2;
    send_key "spc";
    # Make sure it shows the new files from the unpacked tarball
    assert_screen 'yast2_snapper-show_testdata', 100;
    # Close the dialog and make sure it is closed
    send_key "alt-c";
    assert_screen 'yast2_snapper-snapshotlisted', 100;
    # Dele't'e the snapshot
    send_key "alt-t";
    assert_screen 'yast2_snapper-confirm_delete', 100;
    send_key "alt-y";
    assert_screen 'yast2_snapper-nosnapshots', 100;
    # C'l'ose  the snapper module
    send_key "alt-l";
    # Wait until xterm is focussed, delete the subvolume and close xterm
    wait_idle;
    script_run "btrfs subvolume delete /tmp/testdata/.snapshots";
    script_run "rm -rf /tmp/testdata/*";
    script_run "btrfs subvolume delete /tmp/testdata";
    script_run "ls /tmp";
    script_run "exit";
    save_screenshot;
    script_run "exit";
}

1;
# vim: set sw=4 et:
