use base "installbasetest";
use strict;
use testapi;

sub run() {
    # wait booted
    assert_screen 'generic-desktop', 200;

    x11_start_program('xterm');
    become_root;

    type_string "PS1=\$\n";    # set constant shell promt
    sleep 1;

    # Disable console screensaver
    script_run("setterm -blank 0");
}

1;
# vim: set sw=4 et:
