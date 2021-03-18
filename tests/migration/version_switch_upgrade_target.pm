# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Changes the VERSION to UPGRADE_TARGET_VERSION and
#       reload needles.
#       After original system being patched, we need switch
#       VERSION to the target version of upgrade.
# Maintainer: Wei Gao <wegao@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use migration;
use version_utils 'is_sle';
use Utils::Backends 'is_pvm';
use utils;

sub run {
    # After being patched, original system is ready for upgrade
    my $upgrade_target_version = get_required_var('UPGRADE_TARGET_VERSION');

    if (get_var('VERSION') ne $upgrade_target_version) {
        # Switch to upgrade target version and reload needles
        set_var('VERSION', $upgrade_target_version, reload_needles => 1);
    }

    # Reset vars for upgrade on zVM
    if (get_var('UPGRADE_ON_ZVM')) {
        set_var('UPGRADE',             1);
        set_var('AUTOYAST',            0);
        set_var('DESKTOP',             'textmode');
        set_var('SCC_REGISTER',        'installation');
        set_var('REPO_UPGRADE_BASE_0', 0);
        # Set this to load extra needle during scc registration in sle15
        set_var('HDDVERSION', get_var('BASE_VERSION'));
    }

    # Only 11-SP4 need set username, 11-SP4+ don't need set username
    # Reset DESKTOP after upgrade as desktop change
    if (is_sle('=11-SP4', get_var('HDDVERSION')) && check_var('DM_NEEDS_USERNAME', '1')) {
        set_var('DM_NEEDS_USERNAME', '0');
        set_var('DESKTOP',           'gnome') if (check_var('DESKTOP', 'kde') && (get_var('ADDONURL', '') !~ /phub/));
    }

    record_info('Version', 'VERSION=' . get_var('VERSION'));
    if (is_pvm) {
        reconnect_mgmt_console;
    } else {
        reset_consoles_tty;
    }
}

1;
