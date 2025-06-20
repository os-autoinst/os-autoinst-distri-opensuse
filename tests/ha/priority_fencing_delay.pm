# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test the priority fencing delay feature
# The node with the master resource must always win the fencing match
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use hacluster;
use utils qw(zypper_call reconnect_mgmt_console);
use Utils::Backends qw(is_pvm);
use version_utils qw(is_sle);

sub stonith_iptables {
    my ($self, $count, $cluster) = @_;
    my $partner_ip = is_node(1) ? get_ip(choose_node(2)) : get_ip(choose_node(1));

    while ($count != 0) {
        script_run "iptables -A INPUT -s $partner_ip -j DROP; iptables -A OUTPUT -d $partner_ip -j DROP";
        if (is_node(1)) {
            # Wait for the stonith match, then flush the rules for the next test
            script_run "until grep -qi offline <($crm_mon_cmd) ; do sleep 1; done", 60;
            assert_script_run("iptables -F && iptables -X", 180);
        }

        # Node 2 should reboot
        if (is_node(2)) {
            reconnect_mgmt_console if is_pvm;
            # Wait for boot and reconnect to root console
            $self->wait_boot;
            select_console 'root-console';
            # The cluster has to be in a good state before looping to another fencing test
            wait_until_resources_started;
            check_cluster_state;
        }
        # Both nodes are ok
        barrier_wait("STONITH_COUNTER_${count}_$cluster");
        $count--;
    }
}

sub run {
    my ($self) = @_;
    my $cluster_name = get_cluster_name;

    # As this module causes a fence operation, we need to prepare the console for assert_screen
    # on grub2 and bootmenu
    prepare_console_for_fencing;

    # iptables is not installed in SLE 16 by default
    zypper_call 'in iptables' if is_sle('>=16');

    # Configure a master resource on node1 for getting a heavier weight for the priority fencing feature
    if (is_node(1)) {
        assert_script_run "crm configure primitive stateful-1 ocf:pacemaker:Stateful meta priority=129";
        assert_script_run "crm configure clone promotable-1 stateful-1 meta promotable=true";
        assert_script_run "crm resource param stonith-sbd set pcmk_delay_max 15";
        assert_script_run "crm configure property priority-fencing-delay=30";
        # Workaround for bsc#1244437
        if (is_sle('16+') and get_var("WORKAROUND_BSC1244437")) {
            assert_script_run "crm configure location force_primary promotable-1 100: " . get_hostname;
            record_soft_failure 'bsc#1244437 - Priority Fencing Delay configuration requires a cluster restart in 16';
            assert_script_run "crm cluster restart --all";
            wait_until_resources_started;
            check_cluster_state;
        }
    }

    # Informing nodes that the cluster configuration is ready
    barrier_wait("PRIORITY_FENCING_CONF_$cluster_name");

    # Do a check of the cluster with a screenshot
    save_state;

    # Proceed to x stonith tests where x is equal to the STONITH_COUNT variable value
    $self->stonith_iptables(get_required_var("STONITH_COUNT"), $cluster_name);
    barrier_wait("PRIORITY_FENCING_DONE_$cluster_name");
    save_state;
}

1;
