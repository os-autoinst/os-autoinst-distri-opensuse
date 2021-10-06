# SUSE's openQA tests
#
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: add addon to SLES via SCC
#          https://progress.opensuse.org/issues/16402
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base qw(y2_installbase y2_module_guitest);
use strict;
use warnings;
use testapi;
use registration;
use version_utils 'is_sle';
use x11utils 'turn_off_gnome_screensaver';

=head2 test_setup
Define proxy SCC. For SLE 15 we need to clean existing registration
=cut
sub test_setup {
    x11_start_program('xterm');
    turn_off_gnome_screensaver;
    become_root;
    # We use image which is registered, so remove previous registration first
    if (is_sle('>=15')) {
        cleanup_registration();
    }

    my @addon_proxy = ('url: http://' . (is_sle('<15') ? 'server-' : 'all-') . get_var('BUILD_SLE'));
    # Add every used addon to regurl for proxy SCC, sle12 addons can have different build numbers
    if (get_var('SCC_ADDONS') && is_sle('<15')) {
        for my $addon (split(/,/, get_var('SCC_ADDONS', ''))) {
            my $uc_addon = uc $addon;    # change to uppercase to match variable
            push(@addon_proxy, "\b.$addon-" . get_var("BUILD_$uc_addon"));
        }
    }

    assert_script_run "echo \"@addon_proxy.proxy.scc.suse.de\" > /etc/SUSEConnect";    # Define proxy SCC
    wait_screen_change(sub { enter_cmd "exit" }, 5) for (1 .. 2);
}

sub run {
    test_setup;
    y2_module_guitest::launch_yast2_module_x11('scc', target_match => [qw(scc-registration packagekit-warning)], maximize_window => 1);
    if (match_has_tag 'packagekit-warning') {
        send_key 'alt-y';
        assert_screen 'scc-registration';
    }
    fill_in_registration_data;
    assert_screen 'generic-desktop';
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    verify_scc;
    investigate_log_empty_license;
}

sub test_flags {
    # add milestone flag to save setup in lastgood VM snapshot
    return {fatal => 1, milestone => 1};
}

1;
