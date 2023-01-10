# GUEST MIGRATION TEST BARRIERS MODULE
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Create barriers to be used during test run.
#
# Maintainer: Wayne Chen <wchen@suse.com>, qe-virt <qe-virt@suse.de>
package parallel_guest_migration_barrier;

use base "parallel_guest_migration_base";
use strict;
use warnings;
use lockapi;
use mmapi;

sub run {
    my $self = shift;

    $self->create_barrier(signal => 'READY_TO_GO LOCAL_INITIALIZATION_DONE PEER_INITIALIZATION_DONE HOST_PREPARATION_DONE GUEST_PREPARATION_SOURCE_DONE GUEST_PREPARATION_DESTINATION_DONE LOG_PREPARATION_DONE DO_GUEST_MIGRATION_DONE_0 DO_GUEST_MIGRATION_READY_0 POST_FAIL_HOOK_DONE');
}

1;
