use base "opensusebasetest";
use strict;
use testapi;

sub run {
    my $self = shift;

    assert_screen "bootloader-ofw-yaboot", 15;

    type_string "rescue";
    send_key "ret";
    
    if ( check_screen "keyboardmap-list", 100 ) {
        type_string "6\n";
    }
    else {
        record_soft_failure;
    }

    # Login as root (no password)
    assert_screen "rescuesystem-login", 120;
    type_string "root\n";

    # Clean the screen
    sleep 1;
    type_string "reset\n";
    assert_screen "rescuesystem-prompt", 4;
}

sub test_flags() {
    return { 'fatal' => 1, 'important' => 1 };
}

1;
# vim: set sw=4 et:
