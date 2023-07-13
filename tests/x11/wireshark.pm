# SUSE's openQA tests
#
# Copyright 2016-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wireshark
# Summary: Wireshark test
#  Start:
#   - start wireshark in fullscreen
#  Basic GUI:
#  Capture test:
#   - start capturing with the DNS filter set
#   - (from console) generate traffic including a DNS A request
#     for www.suse.com
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
use version_utils 'is_sle';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

# allow a TIMEOUT second timeout for asserting needles
use constant TIMEOUT => 90;

sub run {
    select_serial_terminal();
    quit_packagekit;
    zypper_call "in wireshark";

    select_console 'x11';
    x11_start_program('xterm');
    become_root;
    enter_cmd "wireshark";
    assert_screen("wireshark-welcome", TIMEOUT);
    send_key "super-up";
    assert_screen("wireshark-fullscreen", TIMEOUT);
    send_key "alt-f4";

    ####################
    #   Capture test   #
    ####################
    # Start capture  on interface eth0 with the filter set and dump the capture to a file
    enter_cmd "wireshark -i eth0 -k -Y 'dns.a and dns.qry.name==\"www.suse.com\"' -w /tmp/capture.pcap";
    assert_screen "wireshark-capturing-list";

    select_serial_terminal();
    # Generate the DNS request traffic
    assert_script_run "dig www.suse.com A";
    assert_script_run "host www.suse.com";
    select_console 'x11', await_console => 0;
    wait_still_screen 2;
    assert_and_click("wireshark-dns-response-list", timeout => TIMEOUT);
    assert_and_click "wireshark-dns-response-details";
    send_key "right";
    send_key_until_needlematch "wireshark-dns-response-details-answers", "down";
    wait_still_screen 2;
    assert_and_click "wireshark-dns-response-details-answers";
    send_key_until_needlematch "wireshark-dns-response-details-answers-expanded", "right";
    send_key "up";    # expand 'Queries' as well
    send_key "right";
    assert_screen("wireshark-dns-response-details-queries-expanded", TIMEOUT);
    send_key "down";
    send_key "right";
    assert_screen("wireshark-dns-response-details-queries-expanded2", TIMEOUT);
    send_key("ctrl-e");
    wait_still_screen 1;
    send_key "alt-f4";
    wait_still_screen 2;
    # Load the Capture file
    enter_cmd "wireshark /tmp/capture.pcap -Y 'dns.a and dns.qry.name==\"www.suse.com\"'";
    wait_still_screen 5;
    assert_screen("wireshark-capturing-list", TIMEOUT);
    assert_screen("wireshark-dns-response-list", TIMEOUT);
    send_key "alt-f4";
    wait_still_screen 2;

    enter_cmd "wireshark";
    assert_screen("wireshark-welcome", TIMEOUT);
    wait_still_screen 3;
    # Unselect the display of the Protocol in the UI.
    send_key "ctrl-shift-p";
    assert_screen("wireshark-preferences", TIMEOUT);
    send_key_until_needlematch "wireshark-preferences-columns-protocol-displayed", "down";
    assert_and_click "wireshark-preferences-columns-protocol-unselect";
    assert_screen("wireshark-preferences-columns-protocol-not-displayed-selected", TIMEOUT);
    assert_and_click "wireshark-preferences-apply";
    if (is_sle("=12-sp5")) {
        send_key "alt-f4";
    }
    wait_still_screen 3, 6;
    ####################
    #   Profile test   #
    ####################
    # Create new 'openQA' profile.
    send_key "ctrl-shift-a";
    assert_screen("wireshark-profiles", TIMEOUT);
    assert_and_click "wireshark-profiles-new";
    enter_cmd "openQA";
    wait_still_screen 1;
    send_key "ret";
    assert_screen("wireshark-fullscreen", TIMEOUT);
    # Change back to the Default profile.
    send_key "ctrl-shift-a";
    assert_screen("wireshark-profiles", TIMEOUT);
    assert_and_dclick "wireshark-profiles-default";
    wait_still_screen 3;
    send_key "ret";
    assert_screen("wireshark-fullscreen", TIMEOUT);
    send_key "alt-f4";
    #cleanup
    enter_cmd "rm /tmp/capture.pcap";
    enter_cmd "killall xterm";
    assert_screen('generic-desktop');

}
1;
