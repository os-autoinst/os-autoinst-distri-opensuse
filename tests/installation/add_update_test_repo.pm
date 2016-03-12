# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;
    assert_screen 'inst-addon';
    send_key 'alt-k';    # install with a maint update repo
    foreach my $maintrepo (split(/,/, get_var('MAINT_TEST_REPO'))) {
        assert_screen 'addon-menu-active';
        send_key 'alt-u';    # specify url
        if (check_var('VERSION', '12') and check_var('VIDEOMODE', 'text')) {
            send_key 'alt-x';
        }
        else {
            send_key 'alt-n';
        }
        assert_screen 'addonurl-entry';
        send_key 'alt-u';    # select URL field
        type_string "$maintrepo";
        send_key 'alt-n';
        assert_screen 'addon-products';
        if ((split(/,/, get_var('MAINT_TEST_REPO')))[-1] ne $maintrepo) {    # if $maintrepo is not first from all maint test repos
            send_key 'alt-a';                                                # add another repo
        }
    }
}

1;
# vim: set sw=4 et:
