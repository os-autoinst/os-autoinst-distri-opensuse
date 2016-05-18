# SLE12 online migration tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use strict;
use testapi;
use registration;

sub run() {
    my $self = shift;
    select_console 'root-console';

    if (my $u = get_var('SCC_URL')) {
        type_string "echo 'url: $u' > /etc/SUSEConnect\n";
    }

    # register system and addons in textmode for all archs
    if (get_var("DESKTOP") =~ /textmode|minimalx/) {
        yast_scc_registration;
    }
    else {
        set_var("DESKTOP", 'textmode');
        yast_scc_registration;
        # set back to gnome mode for checking
        # if system boot into desktop correctly after migration
        set_var("DESKTOP", 'gnome');
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
