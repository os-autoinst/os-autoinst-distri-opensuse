# SUSE's openQA tests
#
# Copyright (c) 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Configure DLM in cluster configuration
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use hacluster;

sub run {
    my $cluster_name = get_cluster_name;

    # Wait until DLM test is initialized
    barrier_wait("DLM_INIT_$cluster_name");

    # Test if DLM kernel module package is installed
    die 'dlm kernel package is not installed' unless is_package_installed 'dlm-kmp-default';

    if (is_node(1)) {
        # Create DLM resource
        assert_script_run 'EDITOR="sed -ie \'$ a primitive dlm ocf:pacemaker:controld\'" crm configure edit';
        assert_script_run 'EDITOR="sed -ie \'$ a group base-group dlm\'" crm configure edit';
        assert_script_run 'EDITOR="sed -ie \'$ a clone base-clone base-group\'" crm configure edit';
    }
    else {
        diag 'Wait until DLM resource is created...';
    }

    # Wait until DLM resource is created
    barrier_wait("DLM_GROUPS_CREATED_$cluster_name");

    # DLM process needs to be started
    ensure_process_running 'dlm_controld';

    # Wait until DLM process is checked
    barrier_wait("DLM_CHECKED_$cluster_name");

    # Do a check of the cluster with a screenshot
    save_state;
}

1;
