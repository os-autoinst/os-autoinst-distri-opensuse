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
use warnings;
use base "y2logsstep";
use testapi;
use qam 'advance_installer_window';

sub run() {

    if (get_var('SKIP_INSTALLER_SCREEN', 0)) {
        advance_installer_window('inst-addon');
        # Since we already advanced, we don't want to advance more in the add_products_sle tests
        set_var('SKIP_INSTALLER_SCREEN', 0);
    }

    assert_screen 'inst-addon';
    send_key 'alt-k';    # install with a maint update repo
    my @repos = split(/,/, get_var('MAINT_TEST_REPO'));

    while (defined(my $maintrepo = shift @repos)) {
        next if $maintrepo =~ /^\s*$/;
        assert_screen('addon-menu-active', 60);
        wait_screen_change { send_key 'alt-u' };    # specify url
        if (check_var('VERSION', '12') and check_var('VIDEOMODE', 'text')) {
            send_key 'alt-x';
        }
        else {
            send_key $cmd{next};
        }
        assert_screen 'addonurl-entry';
        send_key 'alt-u';                           # select URL field
        type_string $maintrepo;
        advance_installer_window('addon-products');
        # if more repos to come, add more
        send_key_until_needlematch('addon-menu-active', 'alt-a', 10, 5) if @repos;
    }
}

1;
