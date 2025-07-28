# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Disable kernel incident repositories and force package downgrade.
#          Used mainly for livepatch uninstallation testing.
# Maintainer: Martin Doucha <mdoucha@suse.cz>

use 5.018;
use base 'opensusebasetest';
use testapi;
use utils;

sub run {
    my ($self) = @_;
    my $repo = get_required_var('INCIDENT_REPO');

    for my $uri (split(",", $repo)) {
        zypper_call("mr -d $uri");
    }

    zypper_call('--no-refresh dup --allow-downgrade');

    for my $uri (split(",", $repo)) {
        zypper_call("mr -e $uri");
    }

}

sub test_flags {
    return {
        fatal => 1,
        milestone => 1,
    };
}

=head1 Configuration

This test module is activated when KGRAFT=1 and UNINSTALL_INCIDENT=1.

=cut

1;
