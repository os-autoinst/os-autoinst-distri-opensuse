# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Change the VERSION to ORIGIN_SYSTEM_VERSION and also
#       reload needles.
#       At the beginning of upgrade, we need patch the original
#       system on hdd, which is still old version at the moment.
# Maintainer: Wei Gao <wegao@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use migration;

sub run {
    # Before upgrade or after rollback, switch to original system version
    # Do NOT use HDDVERSION because it might be changed in another test
    # module, such as: reboot_and_install.pm
    my $original_version = get_required_var('ORIGIN_SYSTEM_VERSION');

    if (get_var('VERSION') ne $original_version) {
        # Switch to original system version and reload needles
        set_var('VERSION', $original_version, reload_needles => 1);
    }

    # Reset vars for autoyast installation of origin system
    if (get_var('UPGRADE_ON_ZVM')) {
        set_var('UPGRADE',      0);
        set_var('SCC_REGISTER', 'none');
    }

    record_info('Version', 'VERSION=' . get_var('VERSION'));
    reset_consoles_tty;
}

1;
