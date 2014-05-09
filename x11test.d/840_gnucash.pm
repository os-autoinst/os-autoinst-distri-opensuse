use base "basetest";
use bmwqemu;

sub run() {
    my $self = shift;
    ensure_installed("gnucash");
    ensure_installed("gnucash-docs");

    # needed for viewing
    ensure_installed("yelp");
    x11_start_program("gnucash");
    assert_screen 'test-gnucash-1', 3;
    send_key "ctrl-h";    # open user tutorial
    waitidle 5;
    assert_screen 'test-gnucash-2', 3;
    send_key "alt-f4";    # Leave tutorial window
                         # Leave tips windows for GNOME case
    if ( $ENV{DESKTOP} eq "gnome" || $ENV{DESKTOP} eq "xfce" ) { sleep 3; send_key "alt-c"; }
    waitidle;
    send_key "ctrl-q";    # Exit
}

1;
# vim: set sw=4 et:
