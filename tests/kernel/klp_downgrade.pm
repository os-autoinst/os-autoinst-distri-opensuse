# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Rollback to the previous kernel livepatch.
# Maintainer: Martin Doucha <mdoucha@suse.cz>

use 5.018;
use warnings;
use base 'opensusebasetest';
use testapi;
use utils;

sub run {
    my ($self) = @_;
    my $patches = script_output('klp patches');

    assert_script_run('klp -n downgrade');
    die 'Kernel reports the same livepatches as before downgrade'
      if $patches eq script_output('klp patches');
}

sub test_flags {
    return {
        fatal => 1,
        milestone => 1,
    };
}

=head1 Configuration

This test module is activated when KGRAFT=1 and KGRAFT_DOWNGRADE=1.

=cut

1;
