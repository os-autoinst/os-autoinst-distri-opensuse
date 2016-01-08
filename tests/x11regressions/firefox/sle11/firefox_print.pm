
##################################################
# Written by:    Xudong Zhang <xdzhang@suse.com>
# Case:        1248979
#Description:    Firefox Print
#
#1.Go to http://www.novell.com
#2.Select File-> Print or click the toolbar Print icon.
#3.Print the page and check the hard copy output.
##################################################

use strict;
use base "basetest";
use testapi;

sub run() {
    my $self = shift;
    mouse_hide();
    x11_start_program("firefox");
    assert_screen "start-firefox", 5;
    if (get_var("UPGRADE")) { send_key "alt-d"; wait_idle; }    # dont check for updated plugins
    if (get_var("DESKTOP") =~ /xfce|lxde/i) {
        send_key "ret";                                         # confirm default browser setting popup
        wait_idle;
    }

    send_key "ctrl-l";
    sleep 1;
    type_string "ftp://ftp.novell.com" . "\n";
    sleep 5;                                                    #open the novell.com
    send_key "ctrl-p";
    sleep 1;
    check_screen "firefox_print", 3;
    for (1 .. 2) {                                              #
        send_key "tab";
        sleep 1;
    }
    send_key "left";
    sleep 1;
    type_string "/home/" . $username . "/" . "\n";              #firefox-bug 894966
    sleep 5;

    #check the pdf file
    x11_start_program("evince /home/" . $username . "/" . "mozilla.pdf");
    sleep 4;
    check_screen "firefox_printpdf_evince", 5;
    send_key "alt-f4";
    sleep 2;                                                    #close evince

    #delete the "mozilla.pdf" file
    x11_start_program("rm /home/" . $username . "/" . "mozilla.pdf");

    send_key "alt-f4";
    sleep 2;
    send_key "ret";
    sleep 2;                                                    # confirm "save&quit"
}

1;

# vim: set sw=4 et:
