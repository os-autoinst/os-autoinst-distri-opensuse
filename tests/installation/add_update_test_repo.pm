# SUSE's openQA tests
#
# Copyright © 2016-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Support installation testing of SLE 12 with unreleased maint updates
# Maintainer: Stephan Kulow <coolo@suse.de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;
use qam 'advance_installer_window';
use maintenance_smelt qw(repo_is_not_active);

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
        next if repo_is_not_active($maintrepo);
        assert_screen('addon-menu-active', 60);
        send_key 'alt-u';    # specify url
        wait_still_screen(1);
        send_key $cmd{next};
        wait_still_screen(1);
        assert_screen 'addonurl-entry';
        send_key 'alt-u';    # select URL field
        type_string $maintrepo;
        advance_installer_window('addon-products');
        # if more repos to come, add more
        send_key_until_needlematch('addon-menu-active', 'alt-a', 10, 2) if @repos;
    }

    # when last maintrepo was released thus not added, previous loop will end in addon-menu-active
    # expecting another entry and fail as there is no next repo to add
    if (get_var('FLAVOR', '') =~ /-Updates/) {
        wait_still_screen(2);
        if (check_screen('addon-menu-active')) {
            # go back to registration and forward to addons
            send_key 'alt-b';
            wait_still_screen(2);
            send_key 'alt-n';
        }
    }
}

1;
