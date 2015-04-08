use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    assert_screen 'smt-configuration-1';
    send_key 'alt-u';   # User field
    type_string "user";
    send_key 'tab';     # Password
    type_string "passw";
    send_key 'alt-n';   # next
    assert_screen 'smt-configuration-2';
    send_key 'alt-d';   # Database password for smt user
    type_string "passw";
    send_key 'tab';
    type_string "passw";
    send_key 'alt-n';   # next
    assert_screen 'ncc-credentials';
    send_key 'alt-g';   # Generate new NCC credentials
    send_key 'alt-n';   # next
    assert_screen 'mysql-password';
    type_string "passw"; # mysql root password
    send_key 'tab';
    type_string "passw";
    send_key 'alt-o';
    assert_screen 'smt-configuration-3';
    send_key 'alt-o';   # OK
}

1;
# vim: set sw=4 et:
