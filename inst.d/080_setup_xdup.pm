use base "basetest";
use strict;
use bmwqemu;

sub is_applicable() {
    return $envs->{ZDUP} || $envs->{WDUP};
}

sub run() {

    # wait booted
    sleep 30;
    waitidle;

    # log into text console
    send_key "ctrl-alt-f4";
    sleep 2;
    type_string "$username\n";
    sleep 2;
    sendpassword;
    type_string "\n";
    sleep 3;
    type_string "PS1=\$\n";    # set constant shell promt
    sleep 1;
}

1;
# vim: set sw=4 et:
