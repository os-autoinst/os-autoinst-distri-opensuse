use base "x11test";
use strict;
use testapi;

# Case 1436022 - Evince: Find
sub run() {
    my $self = shift;
    x11_start_program("evince " . autoinst_url . "/data/x11regressions/test.pdf");

    send_key "ctrl-f";    # show search toolbar
    assert_screen 'evince-search-toolbar', 5;

    type_string 'To search for';
    assert_screen 'evince-search-1stresult', 10;

    for ( 1..2 ) {
        send_key "ctrl-g";    # go to next result
    }
    assert_screen 'evince-search-3rdresult', 5;

    for ( 1..2 ) {
        send_key "ctrl-shift-g";    # go to previous result
    }
    assert_screen 'evince-search-1stresult', 5;
    
    send_key "esc", 1;
    send_key "ctrl-w";
}

1;
# vim: set sw=4 et:
