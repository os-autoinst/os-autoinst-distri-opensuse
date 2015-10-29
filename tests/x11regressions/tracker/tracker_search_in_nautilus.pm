use base "x11test";
use strict;
use testapi;

sub run() {
    my $self = shift;
    x11_start_program("nautilus");
    wait_idle;
    send_key "ctrl-f";
    sleep 2;
    type_string "newfile";
    wait_idle;
    send_key "ret";
    wait_idle;
    assert_screen 'gedit-launched', 3;    # should open file newfile
    send_key "alt-f4";
    sleep 2;                              #close gedit
    send_key "alt-f4";
    sleep 2;                              #close nautilus
}

1;
# vim: set sw=4 et:
