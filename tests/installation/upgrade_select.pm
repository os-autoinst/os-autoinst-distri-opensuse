# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Select existing partition(s) for upgrade
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use base "y2logsstep";
use testapi;
use utils 'assert_screen_with_soft_timeout';
use version_utils 'is_sle';

sub run {
    if (get_var('ENCRYPT')) {
        assert_screen [qw(upgrade-unlock-disk upgrade-enter-password)];
        # New Storage NG dialog already contains the password entry.
        # The old dialog needed another click to proceed to the password entry:
        if (!match_has_tag("upgrade-enter-password")) {
            send_key 'alt-p';    # provide password
            assert_screen "upgrade-enter-password";
        }
        type_password;
        send_key $cmd{ok};
    }

    # hardware detection and waiting for updates from suse.com can take a while
    assert_screen_with_soft_timeout('select-for-update', timeout => 500, soft_timeout => 100, bugref => 'bsc#1028774');
    send_key $cmd{next};
    assert_screen [qw(remove-repository license-agreement license-agreement-accepted)], 240;
    if (match_has_tag("license-agreement") || match_has_tag("license-agreement-accepted")) {
        send_key 'alt-a' unless match_has_tag("license-agreement-accepted");
        record_soft_failure 'bsc#1080450: license agreement is shown twice' if match_has_tag("license-agreement-accepted");
        send_key $cmd{next};
        assert_screen "remove-repository";
    }
    send_key $cmd{next};
    # Select migration target in sle15 upgrade
    if (is_sle '15+') {
        if (get_var('MEDIA_UPGRADE')) {
            assert_screen 'upgrade-unregistered-system';
            send_key $cmd{ok};
        }
        else {
            # Ensure we are in 'Select the Migration Target' page
            assert_screen 'select-migration-target', 120;
            send_key 'alt-p';
            # Confirm default migration target matches correct base product
            my $migration_target_base = 'migration_target_' . lc(get_var('SLE_PRODUCT', 'sles')) . lc(get_var('VERSION'));
            # Scroll to the end to assert target base product if the text is longer than box
            assert_screen ["$migration_target_base", 'migration_target_hscrollbar'];
            if (match_has_tag 'migration_target_hscrollbar') {
                assert_and_click 'migration_target_hscrollbar';
                assert_screen "$migration_target_base";
            }
            # Confirm other migration targets match the same base product
            # Assume no more than 6 possible migration targets
            for (1 .. 5) {
                send_key 'down';
                unless (check_screen $migration_target_base, 30) {
                    record_info 'Likely error detected', 'Incorrect migration target? See https://fate.suse.com/323165', result => 'fail';
                    last;
                }
            }
            # Back to default migration target
            wait_screen_change {
                send_key 'home';
            };
            save_screenshot;

            send_key $cmd{next};
        }
    }
}

1;
