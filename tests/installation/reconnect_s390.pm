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
    my $self = shift;

    console('iucvconn')->kill_ssh;

    console('x3270')->expect_3270(
        output_delim => qr/Welcome to SUSE Linux Enterprise Server/,
        timeout      => 300
    );

    reset_consoles;
    # reconnect the ssh for grab
    select_console('iucvconn');

    if (!check_var('DESKTOP', 'textmode')) {
        select_console('x11');
    }
}

1;
