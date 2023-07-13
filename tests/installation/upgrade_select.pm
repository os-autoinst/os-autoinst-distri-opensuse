# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Select existing partition(s) for upgrade
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use utils 'assert_screen_with_soft_timeout';
use version_utils qw(is_sle is_opensuse is_leap);

sub run {
    if (get_var('ENCRYPT')) {
        assert_screen [qw(upgrade-unlock-disk upgrade-enter-password)];
        # New Storage NG dialog already contains the password entry.
        # The old dialog needed another click to proceed to the password entry:
        if (!match_has_tag("upgrade-enter-password")) {
            send_key 'alt-p';    # provide password
            assert_screen "upgrade-enter-password";
        }
        type_password();
        send_key is_sle('<=15-SP4') || is_leap('<15.4') ?
          $cmd{ok} :
          'alt-d';
    }

    # hardware detection and waiting for updates from suse.com can take a while
    # Add tag 'all-partition' for poo#54050 - Need to show all Partition or the base partition for continous migration from SLE11SP4 won't be shown
    assert_screen_with_soft_timeout([qw(select-for-update all-partition)], timeout => 500, soft_timeout => 100, bugref => 'bsc#1028774');
    if (match_has_tag("all-partition")) {
        send_key 'alt-s';
        send_key $cmd{next};
    }
    if (match_has_tag("select-for-update")) {
        my $arch = get_var("ARCH");
        assert_screen('select-for-update-' . "$arch");
        send_key $cmd{next};
    }
    # The SLE15-SP2 license page moved after registration.
    if (get_var('MEDIA_UPGRADE') || is_sle('<15-SP2') || is_opensuse) {
        assert_screen [qw(remove-repository license-agreement license-agreement-accepted)], 240;
        if (match_has_tag("license-agreement")) {
            send_key 'alt-a';
            assert_screen('license-agreement-accepted');
            send_key $cmd{next};
            assert_screen "remove-repository";
        }
        send_key $cmd{next};
    }
    # Select migration target in sle15 upgrade
    if (is_sle '15+') {
        if (get_var('MEDIA_UPGRADE')) {
            # No 'unregistered system' warning message shown when using Full installation image on SLE15SP2
            if (is_sle('<15-SP2')) {
                assert_screen 'upgrade-unregistered-system';
                send_key $cmd{ok};
            }
        }
        else {
            # Ensure we are in 'Select the Migration Target' page
            assert_screen 'select-migration-target', 120;
            wait_still_screen 2;
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
