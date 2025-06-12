# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: crmsh
# Summary: Execute fence command on one of the cluster nodes
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use hacluster qw(check_cluster_state
  choose_node
  get_cluster_name
  get_hostname
  get_node_to_join
  is_node
  prepare_console_for_fencing
);
use version_utils qw(is_sles4sap is_sle);
use bootloader_setup qw(add_grub_cmdline_settings);
use Utils::Logging qw(record_avc_selinux_alerts);

sub run {
    my $cluster_name = get_cluster_name;
    my $node_to_fence = get_var('NODE_TO_FENCE', undef);
    my $node_index = !defined $node_to_fence ? 1 : 2;

    # As this module causes a fence operation, we need to prepare the console for assert_screen
    # on grub2 and bootmenu
    prepare_console_for_fencing;

    # Check cluster state *before* fencing
    barrier_wait("CHECK_BEFORE_FENCING_BEGIN_${cluster_name}_NODE${node_index}");
    check_cluster_state;
    barrier_wait("CHECK_BEFORE_FENCING_END_${cluster_name}_NODE${node_index}");

    # Give time for HANA to replicate the database
    if (check_var('CLUSTER_NAME', 'hana')) {
        'sles4sap'->check_replication_state;
        'sles4sap'->check_hanasr_attr;
        save_screenshot;
        barrier_wait("HANA_REPLICATE_STATE_${cluster_name}_NODE${node_index}");
    }

    # Modify SELinux configurtion file to take permissive mode effect after rebooting
    if (get_var("WORKAROUND_BSC1239148") && is_sles4sap()) {
        add_grub_cmdline_settings('enforcing=0', update_grub => 1);
    }

    # Fence a node with sysrq, crm node fence or by killing corosync
    # Sysrq fencing is more a real crash simulation
    if (get_var('USE_SYSRQ_FENCING') || get_var('USE_PKILL_COROSYNC_FENCING')) {
        my $cmd = 'echo b > /proc/sysrq-trigger';
        $cmd = 'pkill -9 corosync' if (get_var('USE_PKILL_COROSYNC_FENCING'));
        record_info('Fencing info', "Fencing done by [$cmd]");
        enter_cmd $cmd if ((!defined $node_to_fence && check_var('HA_CLUSTER_INIT', 'yes')) || (defined $node_to_fence && get_hostname eq "$node_to_fence"));
    }
    else {
        record_info('Fencing info', 'Fencing done by crm');
        if (defined $node_to_fence) {
            assert_script_run "crm -F node fence $node_to_fence" if (get_hostname ne "$node_to_fence");
        } else {
            assert_script_run 'crm -F node fence ' . get_node_to_join if is_node(2);
        }
    }

    # Wait for server to restart on $node_to_fence or on the master node if no node is specified
    # This loop waits for 'root-console' to disappear, then 'boot_to_desktop' (or something similar) will take care of the boot
    if ((!defined $node_to_fence && check_var('HA_CLUSTER_INIT', 'yes')) || (defined $node_to_fence && get_hostname eq "$node_to_fence")) {
        # Wait at most for 5 minutes (TIMEOUT_SCALE could increase this value!)
        my $loop_count = bmwqemu::scale_timeout(300);
        while (check_screen('root-console', 0, no_wait => 1)) {
            sleep 1;
            $loop_count--;
            last if !$loop_count;
        }
    }

    # In case of HANA cluster we also have to test the failback/takeback after the first fencing
    if (check_var('CLUSTER_NAME', 'hana') && !defined $node_to_fence) {
        set_var('TAKEOVER_NODE', choose_node(2));
    } else {
        set_var('TAKEOVER_NODE', choose_node(1)) if check_var('CLUSTER_NAME', 'hana');
    }
}

# Avoid calling hacluster::post_run_hook(). It will fail on fenced node
# But collect SELinux AVCs on non fenced node
sub post_run_hook {
    my ($self) = @_;
    my $node_to_fence = get_var('NODE_TO_FENCE', undef);
    # If NODE_TO_FENCE is undef, then the module fences first node only, otherwise check for the hostname
    if ((defined $node_to_fence && (get_hostname ne $node_to_fence)) || (!defined $node_to_fence && !check_var('HA_CLUSTER_INIT', 'yes'))) {
        record_avc_selinux_alerts() if is_sle('16+');
    }
}

1;
