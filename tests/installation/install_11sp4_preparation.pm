# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Remove gnome and add kde pattern for migration from SLES11SP4+kde
# - For test scenario of migration from SLES11SP4+kde to SLES15SP3, gnome
# pattern is selected by default, we need remove gnome environment pattern
# then add kde environment pattern before start installation.
# Maintainer: Lemon Li <leli@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;
    if (check_var('DESKTOP', 'kde')) {
        send_key_until_needlematch 'packages-section-selected', 'tab';
        send_key 'ret';
        assert_screen 'software-selection';
        send_key_until_needlematch 'gnome-desk-env-selected', 'down';
        send_key ' ';    #deselect gnome
        assert_screen 'gnome-desk-env';
        send_key_until_needlematch 'kde-desk-env', 'down';
        send_key ' ';    #select kde
        assert_screen 'kde-desk-env-selected';
        send_key 'alt-o';
        assert_screen([qw(confirmlicense pattern-switch-done)]);
        if (match_has_tag('confirmlicense')) {
            send_key $cmd{acceptlicense};
        }
    }
}

1;
