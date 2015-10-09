use base "opensusebasetest";
use strict;
use testapi;

sub run {
    my $self = shift;

    assert_screen "inst-bootmenu", 15;

    if (get_var('OFW')) {
        send_key_until_needlematch 'inst-rescuesystem', 'up';
    } else {
       send_key_until_needlematch('inst-rescuesystem', 'down', 10, 5);
    }
    send_key "ret";

    if ( check_screen "keyboardmap-list", 100 ) {
        send_key "ret";
    }
    else {
        record_soft_failure;
    }

    # Login as root (no password)
    assert_screen "rescuesystem-login", 20;
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
