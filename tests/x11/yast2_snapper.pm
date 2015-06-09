use base "x11test";
use testapi;

# Test for basic yast2-snapper functionality. It assumes the data of the
# opensuse distri to be available at /home/$username/data (as granted by
# console_setup.pm)

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
    script_run "cd";
    # Start the yast2 snapper module and wait until it is started
    script_run "yast2 snapper";
    assert_screen 'yast2_snapper-no_new_snapshot', 100;
    # Create a new snapshot
    $self->y2snapper_create_snapshot();
    # Make sure the snapshot is listed in the main window
    assert_screen 'yast2_snapper-new_snapshot', 100;
    # C'l'ose  the snapper module
    send_key "alt-l";
    # Download & untar test files
    wait_idle;
    script_run "tar -xzf /home/$username/data/yast2_snapper.tgz && echo tar_complete > /dev/$serialdev";
    wait_serial('tar_complete') || die 'tar -xzf failed';
    # Start the yast2 snapper module and wait until it is started
    script_run "yast2 snapper";
    # Make sure the snapper module is started
    assert_screen 'yast2_snapper-new_snapshot', 100;
    # Select the new snapshot
    send_key "down";
    sleep 2;
    send_key "down";
    sleep 2;
    send_key "down";
    sleep 2;
    # Press 'S'how changes button and select both directories that have been
    # extracted from the tarball
    send_key "alt-s";
    assert_screen 'yast2_snapper-collapsed_testdata', 100;
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
    assert_screen 'yast2_snapper-new_snapshot', 100;
    # Select the new snapshot
    send_key "down";
    sleep 2;
    send_key "down";
    sleep 2;
    send_key "down";
    sleep 2;
    # Dele't'e the snapshot
    send_key "alt-t";
    assert_screen 'yast2_snapper-confirm_delete', 100;
    send_key "alt-y";
    assert_screen 'yast2_snapper-no_new_snapshot', 100;
    # C'l'ose  the snapper module
    send_key "alt-l";
    # Wait until xterm is focussed, delete the directory and close xterm
    wait_idle;
    script_run "rm -rf testdata";
    script_run "ls";
    script_run "exit";
    save_screenshot;
    script_run "exit";
}

1;
# vim: set sw=4 et:
