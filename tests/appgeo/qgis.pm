# SUSE's openQA tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install qgis and perform a smoke test
# Maintainer: Guillaume <guillaume@opensuse.org>

use base 'x11test';
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
