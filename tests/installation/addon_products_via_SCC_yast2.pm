# SUSE's openQA tests
#
# Copyright © 2012-2019 SUSE LLC
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
use version_utils 'is_sle';
use x11utils 'turn_off_gnome_screensaver';

=head2 test_setup
Define proxy SCC. For SLE 15 we need to clean existing registration
=cut
sub test_setup {
    select_console 'root-console';
    if (is_sle('>=15')) {
        assert_script_run 'SUSEConnect --clean';                                          # Remove registration from the system
        assert_script_run 'echo "url: ' . get_var('SCC_URL') . '" > /etc/SUSEConnect';    # Define proxy SCC
    }
    elsif (get_var('SCC_ADDONS')) {
        # Add every used addon to regurl for proxy SCC
        my @addon_proxy = ("url: http://server-" . get_var('BUILD_SLE'));
        for my $addon (split(/,/, get_var('SCC_ADDONS', ''))) {
            my $uc_addon = uc $addon;                                                     # change to uppercase to match variable
            push(@addon_proxy, "\b.$addon-" . get_var("BUILD_$uc_addon"));
        }
        assert_script_run "echo \"@addon_proxy.proxy.scc.suse.de\" > /etc/SUSEConnect";    # Define proxy SCC
    }
    turn_off_gnome_screensaver;
    select_console 'x11';
}

sub run {
    my ($self) = @_;

    test_setup;
    $self->launch_yast2_module_x11('scc', target_match => [qw(scc-registration packagekit-warning)], maximize_window => 1);
    if (match_has_tag 'packagekit-warning') {
        send_key 'alt-y';
        assert_screen 'scc-registration';
    }
    fill_in_registration_data;
    assert_screen 'generic-desktop';
}

1;
