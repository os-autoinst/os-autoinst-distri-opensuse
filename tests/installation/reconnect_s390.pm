# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
