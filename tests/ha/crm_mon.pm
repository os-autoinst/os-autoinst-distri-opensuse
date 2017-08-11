# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check cluster status in crm_mon
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'hacluster';
use strict;
use testapi;
use autotest;
use lockapi;

sub run {
    my $self = shift;

    # Synchronize nodes
    barrier_wait('MON_INIT_' . $self->cluster_name);

    # Show cluster informations
    assert_script_run 'crm_mon -R -1';
    assert_script_run 'crm_mon -1 | grep \'partition with quorum\'';
    assert_script_run 'crm_mon -s | grep "$(crm node list | wc -l) nodes online"';

    # Synchronize nodes
    barrier_wait('MON_CHECKED_' . $self->cluster_name);
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

sub post_fail_hook {
    my $self = shift;

    # Save a screenshot before trying further measures which might fail
    save_screenshot;

    # Try to save logs as a last resort
    $self->export_logs();
}

1;
# vim: set sw=4 et:
