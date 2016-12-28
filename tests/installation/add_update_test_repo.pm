# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Support installation testing of SLE 12 with unreleased maint updates
# Maintainer: Stephan Kulow <coolo@suse.de>

use strict;
use base "y2logsstep";
use testapi;

sub run() {
    assert_screen 'inst-addon';
    send_key 'alt-k';    # install with a maint update repo
    my @repos = split(/,/, get_var('MAINT_TEST_REPO'));
    while (my $maintrepo = shift @repos) {
        assert_screen('addon-menu-active', 60);
        send_key 'alt-u';    # specify url
        if (check_var('VERSION', '12') and check_var('VIDEOMODE', 'text')) {
            send_key 'alt-x';
        }
        else {
            send_key $cmd{next};
        }
        assert_screen 'addonurl-entry';
        send_key 'alt-u';    # select URL field
        type_string $maintrepo;
        send_key $cmd{next};
        assert_screen 'addon-products';
        # if more repos to come, add more
        send_key 'alt-a' if @repos;
    }
}

1;
# vim: set sw=4 et:
