# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Install qgis and perform a smoke test
# Maintainer: Guillaume <guillaume@opensuse.org>

use base 'x11test';
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;

    ensure_installed('qgis');

    my @tags = qw(qgis qgis-welcome);
    x11_start_program('qgis', target_match => \@tags);

    if (check_screen('qgis-welcome')) {
        # Close tip of day
        wait_screen_change { send_key 'esc'; };
    }

    # Check we have the qgis main window
    assert_screen('qgis');

    # Close QGIS
    send_key 'alt-f4';

}

1;
