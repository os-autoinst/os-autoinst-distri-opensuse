# SUSE's openQA tests
#
# Copyright (c) 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add some workarounds after upgrade from a SLE11-SP4
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use utils 'systemctl';
use testapi;
use lockapi;
use hacluster;

# Do some stuff that need to be workaround in SLE15
sub run {
    return unless check_var('HDDVERSION', '11-SP4');

    my ($self)        = @_;
    my $cluster_name  = get_cluster_name;
    my $corosync_conf = '/etc/corosync/corosync.conf';
    my $crm_conf      = '/tmp/crm_conf.save';

    # We execute this test after a reboot, so we need to log in
    select_console 'root-console';

    # In 2-node migration from SLES+HA 11-SP4, host name resolution
    # is needed earlier than in other test cases to apply the workarounds
    # needed by the cluster after migration. We'll add the hosts
    # to /etc/hosts if name resolution is failing
    if (is_node(1) or is_node(2)) {
        my $hostname = get_hostname;
        my $partner  = $hostname;
        $partner =~ s/node([0-9]+)$/node/;
        $partner = $1 eq '01' ? $partner . "02" : $partner . "01";

        my $ret_q1 = script_run "host $hostname";
        my $ret_q2 = script_run "host $partner";

        if ($ret_q1 or $ret_q2) {
            record_info "Name resolution failing", "Cannot resolve own name or name of partner. Will attempt to add hosts to /etc/hosts", result => 'softfail';
            my $device = get_var('SUT_NETDEVICE', 'eth0');
            my $addr = script_output "ip -4 addr show dev $device | sed -rne '/inet/s/[[:blank:]]*inet ([0-9\\.]*).*/\\1/p'";
            if ($addr =~ m/10\.0\.2/) {    # Expected addresses are 10.0.2.17 and 10.0.2.18
                assert_script_run "echo \"$addr  $hostname\" >> /etc/hosts";
                $addr =~ s/\.([0-9]+)$/\./;
                $addr = $1 eq '17' ? $addr . "18" : $addr . "17";
                assert_script_run "echo \"$addr  $partner\" >> /etc/hosts";
            }
            else {
                record_info "Unexpected IP Address", "Could not determine IP addresses. Got $addr";
            }
        }
    }

    # Modify the Corosync configuration only on the first node
    assert_script_run "curl -f -v " . autoinst_url . "/data/ha/corosync.conf -o ${corosync_conf}" if is_node(1);

    # Activate/deactivate needed services
    systemctl 'disable --now xinetd', ignore_failure => 1;
    systemctl 'enable --now csync2.socket';
    systemctl 'enable --now hawk', ignore_failure => 1;
    systemctl 'enable sbd';
    systemctl 'enable pacemaker';

    # Wait for all nodes to finish
    barrier_wait("SLE11_UPGRADE_INIT_$cluster_name");

    # Synchronize all cluster files/configuration
    sleep 10 unless is_node(1);
    assert_script_run 'csync2 -v -x -F ; sleep 2 ; csync2 -v -x -F';

    # Modify the RAs, as some of them are different in SLE11
    if (is_node(1)) {
        # Start pacemaker to be able to modify the configuration
        systemctl 'start pacemaker';

        # Pacemaker takes little to automatically adapt the configuration during first boot
        sleep 30;
        assert_script_run "crm configure save $crm_conf";
        assert_script_run "sed -i 's/ocf:lvm2:clvmd/clvm/;/expected-quorum-votes/d' $crm_conf";
        script_run "yes | crm configure load replace $crm_conf";
    }

    # Wait for all nodes
    barrier_wait("SLE11_UPGRADE_START_$cluster_name");

    # Start pacemaker on the other nodes
    systemctl 'start pacemaker' if !is_node(1);

    # Screenshot before cleaning the screen
    save_screenshot;

    # Reset the console on all nodes, as the next test will re-select them
    $self->clear_and_verify_console;

    # Wait for all nodes to finish
    barrier_wait("SLE11_UPGRADE_DONE_$cluster_name");
}

1;
