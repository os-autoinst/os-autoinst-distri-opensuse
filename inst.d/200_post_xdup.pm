use base "basetest";
use strict;
use bmwqemu;

sub is_applicable() {
    return $ENV{ZDUP} || $ENV{WDUP};
}

sub run() {

    # make sure we are on a text console (workaround restart-X11 bug)
    send_key "ctrl-alt-f4";

    # reboot after dup
    send_key "ctrl-alt-delete";
    script_sudo_logout;
    sleep 50;
}

1;
# vim: set sw=4 et:
