use base "opensusebasetest";
use strict;
use testapi;

sub run {
    my $self = shift;

    $self->select_bootmenu_option('inst-rescuesystem', 1);

    if (check_screen "keyboardmap-list", 100) {
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
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
