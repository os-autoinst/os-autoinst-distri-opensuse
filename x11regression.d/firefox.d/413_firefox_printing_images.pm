#!/usr/bin/perl -w

###########################################################
# Test Case:	1248954
# Case Summary: Firefox: Test printing in firefox
# Written by:	wnereiz@github
###########################################################

# Needle Tags:
# firefox-open

# CAUTION:
# This test is one part of case #124895, see the tables in 412_firefox_printing.pm for detail.
#
#
# Note: Mozilla printing test main page:
#       http://www-archive.mozilla.org/quality/browser/front-end/testcases/printing/

use strict;
use base "basetest";
use bmwqemu;

sub run() {
    my $self = shift;
    mouse_hide();

    # Launch firefox
    x11_start_program("firefox");
    assert_screen "start-firefox", 5;
    if ( $vars{UPGRADE} ) { send_key "alt-d"; wait_idle; }    # Don't check for updated plugins
    if ( $vars{DESKTOP} =~ /xfce|lxde/i ) {
        send_key "ret";                                      # Confirm default browser setting popup
        wait_idle;
    }
    send_key "alt-f10";
    sleep 1;                                                # Maximize

    # Define the pages to be tested (last part of urls)

    my @test_images = (

        { name => 'small_gif',    image_file => 'neticon.gif' },
        { name => 'large_gif',    image_file => 'toucan.gif' },
        { name => 'small_jpg',    image_file => 'station.jpg' },
        { name => 'large_jpg',    image_file => 'MoonBkside.jpg' },
        { name => 'animated_gif', image_file => 'aflag.gif' },

    );

    # Define base url
    my $base_url = "www-archive.mozilla.org/quality/browser/front-end/testcases/printing/";

    foreach (@test_images) {

        send_key "alt-d";
        sleep 1;
        type_string $base_url. $_->{image_file} . "\n";    # Full URL
        sleep 8;

        send_key "ctrl-p";
        sleep 1;                                            # Open "Print" window

        send_key "tab";                                      # Choose "Print to File"

        # Set file name
        send_key "alt-n";
        sleep 1;
        type_string $_->{name} . ".pdf";

        # Print
        send_key "alt-p";
        sleep 5;

        # Open printed pdf file by evince
        x11_start_program( "evince " . $_->{name} . ".pdf" );
        sleep 3;
        send_key "f5";
        sleep 2;    # Slide mode

        check_screen "test-firefox_printing_images-" . $_->{name}, 5;
        sleep 1;

        send_key "esc";
        sleep 1;
        send_key "alt-f4";
        sleep 1;    # Close evince
    }

    # Restore and close firefox
    x11_start_program("killall -9 firefox evince");    # Exit firefox. Kill evince at the same time in case of it still there.
    x11_start_program("rm -rf .mozilla");              # Clear profile directory
    x11_start_program("rm *.pdf");                     # Remove all printed pdf files
    sleep 1;
}

1;
# vim: set sw=4 et:
