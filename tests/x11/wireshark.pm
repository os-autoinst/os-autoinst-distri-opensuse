# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
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
# Maintainer: Romanos Dodopoulos <romanos.dodopoulos@suse.cz>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;

sub run() {
    select_console 'x11';
    x11_start_program "xterm";
    become_root;
    pkcon_quit;
    zypper_call "in wireshark";

    # start
    if (check_var("VERSION", "Tumbleweed")) {
        type_string "wireshark-gtk\n";
    }
    else {    # works for SLE12SP1 & SLE12SP2
        type_string "wireshark\n";
    }
    assert_screen "wireshark-welcome", 30;
    send_key "super-up";
    assert_screen "wireshark-fullscreen";

    # check GUI/file set
    assert_and_click "wireshark-file";
    send_key_until_needlematch "wireshark-file-set", "down";
    assert_and_click "wireshark-file-set-list";
    assert_screen "wireshark-file-set-lists";
    send_key "alt-f4";
    assert_screen "wireshark-fullscreen";

    ####################
    #   Capture test   #
    ####################
    # start capturing
    assert_and_click "wireshark-interfaces";
    send_key "spc";
    assert_and_click "wireshark-interfaces-start";
    assert_screen "wireshark-capturing";
    assert_screen "wireshark-capturing-list";

    # generate traffic
    select_console 'root-console';
    wait_still_screen 2;
    assert_script_run "dig www.suse.com A";
    assert_script_run "host www.suse.com";    # check for valid IP address
    select_console 'x11';
    assert_screen "wireshark-capturing";

    # set filter
    assert_screen "wireshark-filter-selected";
    type_string "dns.a and dns.qry.name == \"www.suse.com\"\n";
    assert_screen "wireshark-filter-applied";
    assert_screen "wireshark-capturing";

    # examine capture
    assert_screen "wireshark-dns-response-list";
    assert_and_click "wireshark-dns-response-details";
    send_key "right";
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
    assert_and_click "wireshark-quit-save-tmp";
    assert_and_click "wireshark-quit-save-filename";
    type_string "wireshark-openQA-test\n";
    wait_still_screen 1;
    type_string "\n";    # 2 times return for SP2
    wait_still_screen 1;
    assert_script_run "test -f /tmp/wireshark-openQA-test.pcapng";

    # start and load capture
    type_string "wireshark /tmp/wireshark-openQA-test.pcapng\n";
    assert_screen "wireshark-filter-selected";
    type_string "dns.a and dns.qry.name == \"www.suse.com\"\n";
    assert_screen "wireshark-filter-applied";
    assert_screen "wireshark-dns-response-list";

    # close capture
    assert_and_click "wireshark-close-capture";
    assert_screen "wireshark-fullscreen";

    ####################
    #   Profile test   #
    ####################
    # Create new 'openQA' profile.
    assert_and_click "wireshark-edit";
    assert_and_click "wireshark-edit-profiles";
    assert_screen "wireshark-profiles";
    assert_and_click "wireshark-profiles-new";
    type_string "openQA\n";
    assert_screen "wireshark-fullscreen";

    # Unselect the display of the Protocol in the UI.
    assert_and_click "wireshark-edit";
    assert_and_click "wireshark-edit-preferences";
    assert_screen "wireshark-preferences";
    assert_and_click "wireshark-preferences-columns";
    assert_screen "wireshark-preferences-columns-protocol-displayed";
    assert_and_click "wireshark-preferences-columns-protocol-unselect";
    assert_screen "wireshark-preferences-columns-protocol-not-displayed-selected";
    assert_and_click "wireshark-preferences-apply";
    send_key "alt-f4";
    assert_screen "wireshark-fullscreen";

    # Change back to the Default profile.
    assert_and_click "wireshark-edit";
    assert_and_click "wireshark-edit-profiles";
    assert_screen "wireshark-profiles";
    assert_and_dclick "wireshark-profiles-default";
    assert_screen "wireshark-fullscreen";

    # Verify that the Protocol is properly displayed.
    assert_and_click "wireshark-edit";
    assert_and_click "wireshark-edit-preferences";
    assert_screen "wireshark-preferences";
    assert_and_click "wireshark-preferences-columns";
    assert_screen [qw(wireshark-preferences-columns-protocol-displayed wireshark-preferences-columns-protocol-not-displayed)];
    if (match_has_tag "wireshark-preferences-columns-protocol-not-displayed") {
        record_soft_failure "bsc#1003086";
        assert_and_click "wireshark-preferences-columns-protocol-select";
        assert_screen "wireshark-preferences-columns-protocol-displayed-selected";
        assert_and_click "wireshark-preferences-apply";
    }
    send_key "alt-f4";
    assert_screen "wireshark-fullscreen";
    send_key "alt-f4";

    # clean-up
    assert_script_run "rm /tmp/wireshark-openQA-test.pcapng";
    type_string "exit\n";
    type_string "exit\n";
}
1;
