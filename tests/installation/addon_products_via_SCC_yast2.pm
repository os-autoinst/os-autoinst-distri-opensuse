# SUSE's openQA tests
#
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: add addon to SLES via SCC
#          https://progress.opensuse.org/issues/16402
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base qw(y2logsstep y2x11test);
use strict;
use testapi;
use registration 'fill_in_registration_data';
use version_utils 'sle_version_at_least';
use utils 'turn_off_gnome_screensaver';

sub test_setup {
    select_console 'root-console';
    my $proxy_scc;
    if (sle_version_at_least '15') {
        # Remove registration from the system
        assert_script_run 'SUSEConnect --clean';
        # Define proxy SCC
        assert_script_run 'echo "url: ' . get_var('SCC_URL') . '" > /etc/SUSEConnect';
    }    # add every used addon to regurl for proxy SCC
    elsif (get_var('SCC_ADDONS')) {
        my @addon_proxy = ("url: http://server-" . get_var('BUILD_SLE'));
        for my $addon (split(/,/, get_var('SCC_ADDONS', ''))) {
            my $uc_addon = uc $addon;    # change to uppercase to match variable
            push(@addon_proxy, "\b.$addon-" . get_var("BUILD_$uc_addon"));
        }
        # Define proxy SCC
        assert_script_run "echo \"@addon_proxy.proxy.scc.suse.de\" > /etc/SUSEConnect";
    }
    turn_off_gnome_screensaver;
    select_console 'x11';
}

sub run {
    my ($self) = @_;
    test_setup;                          # Define proxy SCC. For SLE 15 we need to clean existing registration.
    $self->launch_yast2_module_x11('scc', target_match => [qw(scc-registration packagekit-warning)], maximize_window => 1);
    if (match_has_tag 'packagekit-warning') {
        send_key 'alt-y';
        assert_screen 'scc-registration';
    }
    fill_in_registration_data;
    assert_screen 'generic-desktop';
}

1;
# vim: set sw=4 et:
