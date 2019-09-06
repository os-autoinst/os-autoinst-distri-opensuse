# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Wireshark test
#  Start:
#   - start wireshark in fullscreen
#  Basic GUI:
#   - check file set option
#  Capture test:
#   - start capturing
#   - (from console) generate traffic including a DNS A request
#     for www.suse.com
#   - set filter for DNS A
#   - examine capture
#   - save capture
#   - load capture
#   - examine again
#  Profile test:
#   - create new profile
#   - change an option
#   - select default profile
#   - verify the option is not changed
# Maintainer: Veronika Svecova <vsvecova@suse.cz>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'x11';
    x11_start_program('xterm');
    become_root;
    pkcon_quit;
    zypper_call "in wireshark";

    # start
    if (check_var("VERSION", "Tumbleweed")) {
        type_string "wireshark-gtk\n";
    }
    else {    # works for SLE12-SP1+
        type_string "wireshark\n";
    }
    assert_screen "wireshark-welcome", 30;
    send_key "super-up";
    assert_screen "wireshark-fullscreen";

    # check GUI version
    assert_and_click "wireshark-help";
    assert_and_click "about-wireshark";
    assert_screen [qw(wireshark-gui-qt wireshark-gui-gtk)];
    my $wireshark_gui_version = match_has_tag("wireshark-gui-qt") ? "qt" : "gtk";
    assert_and_click "wireshark-about-ok";

    # check GUI/file set
    assert_and_click "wireshark-file";
    send_key_until_needlematch "wireshark-file-set", "down";
    # old GTK UI
    if ($wireshark_gui_version eq "gtk") {
        assert_and_click "wireshark-file-set-list";
        assert_screen "wireshark-file-set-lists";
        send_key "alt-f4";
    }
    # new QT UI greys out List Files item when no files are available
    else {
        send_key "right";
        assert_screen "wireshark-no-files-available";
        send_key "esc";
        wait_still_screen 3;
        send_key "esc";
    }

    assert_screen "wireshark-fullscreen";

    ####################
    #   Capture test   #
    ####################
    # start capturing
    # GTK GUI has the Interfaces menu and all interfaces deselected by default
    if ($wireshark_gui_version eq "gtk") {
        assert_and_click "wireshark-interfaces";
        wait_still_screen 3;
        send_key "spc";
    }
    # QT GUI no longer allows to manage interfaces via dedicated menu item
    else {
        send_key "ctrl-k";
        wait_still_screen 3;
        assert_and_click "wireshark-manage-interfaces";
        wait_still_screen 3;
        assert_screen "wireshark-eth0-selected";
        assert_and_click "wireshark-interfaces-ok";
    }

    assert_and_click "wireshark-interfaces-start";
    assert_screen "wireshark-capturing";
    assert_screen "wireshark-capturing-list";

    # generate traffic
    select_console 'root-console';
    assert_script_run "dig www.suse.com A";
    assert_script_run "host www.suse.com";    # check for valid IP address
    select_console 'x11', await_console => 0;
    assert_screen "wireshark-capturing";

    # set filter
    if ($wireshark_gui_version eq "qt") {
        wait_still_screen 1;
        send_key "ctrl-/";
    }
    assert_screen "wireshark-filter-selected";
    type_string "dns.a and dns.qry.name == \"www.suse.com\"\n";
    assert_screen "wireshark-filter-applied";
    assert_screen "wireshark-capturing";

    # examine capture
    assert_screen "wireshark-dns-response-list";
    assert_and_click "wireshark-dns-response-details";
    send_key "right";
    send_key_until_needlematch "wireshark-dns-response-details-answers", "down";
    assert_and_click "wireshark-dns-response-details-answers";
    send_key "right";
    assert_screen "wireshark-dns-response-details-answers-expanded";
    send_key "up";    # expand 'Queries' as well
    send_key "right";
    assert_screen "wireshark-dns-response-details-queries-expanded";
    send_key "down";
    send_key "right";
    assert_screen "wireshark-dns-response-details-queries-expanded2";

    # save capture and quit
    assert_and_click "wireshark-capturing-stop";
    assert_screen "wireshark-capturing-stopped";
    send_key "ctrl-q";
    wait_still_screen 1;
    assert_and_click "wireshark-quit-save";
    assert_and_click "wireshark-quit-save-filename";
    type_string "/tmp/wireshark-openQA-test\n";
    wait_still_screen 1;
    type_string "\n";    # 2 times return for SP2
    wait_still_screen 1;
    assert_script_run "test -f /tmp/wireshark-openQA-test.pcapng";

    # start and load capture
    type_string "wireshark /tmp/wireshark-openQA-test.pcapng\n";
    wait_still_screen 1;
    # QT menu requires user to place focus in the filter field
    send_key "ctrl-/" if $wireshark_gui_version eq "qt";
    assert_screen "wireshark-filter-selected";
    type_string "dns.a and dns.qry.name == \"www.suse.com\"\n";
    # Sometimes checksum error window popup, then we need close this windows since this caused by offload feature
    assert_screen([qw(wireshark-filter-applied wireshark-checksum-error)]);
    if (match_has_tag('wireshark-checksum-error')) {
        # Close checksum-error window, when we hit this error, the show submenu was extended
        # we need escape the submenu then send alt-c to close the checksum error page.
        send_key "esc";
        wait_still_screen 3;
        send_key "esc";
        wait_screen_change { send_key 'alt-c' };
    }
    else {
        assert_screen "wireshark-dns-response-list";
    }

    # close capture
    assert_and_click "wireshark-close-capture";
    assert_screen "wireshark-fullscreen";

    ####################
    #   Profile test   #
    ####################
    # Create new 'openQA' profile.
    send_key "ctrl-shift-a";
    assert_screen "wireshark-profiles";
    assert_and_click "wireshark-profiles-new";
    type_string "openQA\n";
    # QT GUI does not close Profiles menu window after creating new profile
    if ($wireshark_gui_version eq "qt") {
        wait_still_screen 1;
        send_key "ret";
    }
    assert_screen "wireshark-fullscreen";

    # Unselect the display of the Protocol in the UI.
    send_key "ctrl-shift-p";
    assert_screen "wireshark-preferences";
    assert_and_click "wireshark-preferences-columns";
    assert_screen "wireshark-preferences-columns-protocol-displayed";
    assert_and_click "wireshark-preferences-columns-protocol-unselect";
    assert_screen "wireshark-preferences-columns-protocol-not-displayed-selected";
    assert_and_click "wireshark-preferences-apply";
    wait_still_screen 3;
    send_key "alt-f4" if $wireshark_gui_version eq "gtk";
    assert_screen "wireshark-fullscreen";

    # Change back to the Default profile.
    send_key "ctrl-shift-a";
    assert_screen "wireshark-profiles";
    assert_and_dclick "wireshark-profiles-default";
    wait_still_screen 3;
    # QT GUI does not close window after selecting profile
    send_key "ret" if $wireshark_gui_version eq "qt";
    assert_screen "wireshark-fullscreen";

    # Verify that the Protocol is properly displayed.
    send_key "ctrl-shift-p";
    assert_screen "wireshark-preferences";
    assert_and_click "wireshark-preferences-columns";
    assert_screen 'wireshark-preferences-columns-protocol-displayed';
    send_key "alt-f4";
    assert_screen "wireshark-fullscreen";
    send_key "alt-f4";
    assert_screen "generic-desktop-with-terminal";
    # clean-up
    assert_script_run "rm /tmp/wireshark-openQA-test.pcapng";
    type_string "exit\n";
    type_string "exit\n";
}
1;
