# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Configure DLM in cluster configuration
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'hacluster';
use strict;
use testapi;
use autotest;
use lockapi;

sub run {
    my $self = shift;

    # Wait until DLM test is initialized
    barrier_wait('DLM_INIT_' . $self->cluster_name);

    # Test if DLM kernel module package is installed
    assert_script_run 'rpm -q dlm-kmp-default';

    if ($self->is_node(1)) {
        # Create DLM resource
        assert_script_run 'EDITOR="sed -ie \'$ a primitive dlm ocf:pacemaker:controld op monitor interval=60 timeout=60\'" crm configure edit';
        assert_script_run 'EDITOR="sed -ie \'$ a group base-group dlm\'" crm configure edit';
        assert_script_run 'EDITOR="sed -ie \'$ a clone base-clone base-group\'" crm configure edit';

        # Wait to get DLM running on all nodes
        sleep 10;
    }
    else {
        diag 'Wait until DLM resource is created...';
    }

    # Wait until DLM resource is created
    barrier_wait('DLM_GROUPS_CREATED_' . $self->cluster_name);

    # Wait until DLM process is checked
    assert_script_run 'ps -A | grep -q dlm_controld';
    barrier_wait('DLM_CHECKED_' . $self->cluster_name);

    # Do a check of the cluster with a screenshot
    $self->save_state;
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
