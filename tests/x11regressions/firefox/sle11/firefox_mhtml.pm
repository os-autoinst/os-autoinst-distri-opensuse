#!/usr/bin/perl -w

###########################################################
# Test Case:	1248949, 1248951
# Case Summary: Firefox: MHTML load IE 7 files from local disk in Firefox
# Case Summary: Firefox: MHTML load IE 6 files from web server in Firefox
# Written by:	wnereiz@github
###########################################################

# Needle Tags:
# firefox-open
# test-firefox-openfile-1
# test-firefox_mhtml-1, test-firefox_mhtml-2

use strict;
use base "basetest";
use testapi;

sub run() {
    my $self = shift;
    mouse_hide();

    # Download a mhtml file to the local machine.
    x11_start_program("wget http://www.fileformat.info/format/mime-html/sample/9c96b3d179f84b98b35d4c8c2ec13e04/download -O google.mht");
    sleep 6;

    # Launch firefox
    x11_start_program("firefox");
    assert_screen "start-firefox", 5;
    if ( get_var("UPGRADE") ) { send_key "alt-d"; wait_idle; }    # Don't check for updated plugins
    if ( get_var("DESKTOP") =~ /xfce|lxde/i ) {
        send_key "ret";                                      # Confirm default browser setting popup
        wait_idle;
    }
    send_key "alt-f10";                                      # Maximize

    # Install UnMHT extension
    send_key "ctrl-shift-a";
    sleep 5;                                                # Add-ons Manager
    send_key "alt-d";
    sleep 2;
    type_string "https://addons.mozilla.org/firefox/downloads/latest/8051/addon-8051-latest.xpi\n";
    sleep 15;                                               # Install the extension
    check_screen "test-firefox_mhtml-1", 5;
    send_key "ret";
    sleep 2;
    send_key "ctrl-w";

    # Open mhtml file
    send_key "ctrl-o";
    sleep 1;                                                #"Open File" window
    check_screen "test-firefox-openfile-1", 5;

    # Find .mht file to open
    send_key "left";
    send_key "down";
    send_key "right";
    sleep 1;
    type_string "google\n";                                # find the directory www.gnu.org and enter
    sleep 5;
    send_key "tab";
    check_screen "test-firefox_mhtml-2", 5;
    sleep 2;

    # Open remote mhtml address
    send_key "alt-d";
    sleep 1;
    type_string "http://www.fileformat.info/format/mime-html/sample/9c96b3d179f84b98b35d4c8c2ec13e04/google.mht\n";
    sleep 10;
    check_screen "test-firefox_mthml-3", 5;
    sleep 2;

    # Restore and close

    ###############################################################
    # There are too many trouble to restore the original status.
    # (See the codes below, they have been commented out)
    # So we simply remove the profiles (~/.mozilla/).
    ###############################################################

    # Remove the UnMHT extension
    # send_key "ctrl-shift-a"; sleep 5; # "Add-ons" Manager
    # send_key "ctrl-f"; sleep 1;
    # type_string "unmht\n"; sleep 2; # Search
    # for (1...5){
    #    send_key "tab";sleep 1;
    # }
    # send_key "left"; # Select "My Add-ons"
    # send_key "tab"; send_key "down";
    # for (1...4){
    #     send_key "tab"; sleep 1;
    # }
    # send_key "spc"; sleep 1;# Remove
    # send_key "ctrl-f"; sleep 1;
    # for (1...5){
    #     send_key "tab";sleep 1;
    # }
    # send_key "right";
    # send_key "ctrl-w"; # Close "Add-ons" Manager
    #

    # send_key "ctrl-w"; # Close the only tab (exit)
    # send_key "ret"; sleep 2; # confirm "save&quit"
    # x11_start_program("xterm"); sleep 2;
    # type_string "rm -f ~/.mozilla/firefox/*.default/prefs.js\n"; sleep 1; # Remove prefs.js to avoid browser remember default folder used by "Open File" window
    # send_key "ctrl-d"; # Exit xterm

    send_key "alt-f4";
    sleep 1;                                 # Exit firefox
    send_key "ret";                           # confirm "save&quit"
    x11_start_program("rm -rf .mozilla");    # Clear profile directory
    x11_start_program("rm -rf google.mht\n");
    sleep 1;                                 # Remove .mht file
    sleep 2;

}

1;
# vim: set sw=4 et:
