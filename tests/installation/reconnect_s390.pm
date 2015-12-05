use base "installbasetest";

use testapi;

use strict;
use warnings;

sub run() {

    wait_serial("Welcome to SUSE Linux Enterprise Server", 300);
    sleep 30;    #FIXME Slight delay to make sure the machine has really started and is ready for connection via SSH

    reset_consoles;
    if (!check_var('DESKTOP', 'textmode')) {
        select_console('x11');
    }
}

1;
