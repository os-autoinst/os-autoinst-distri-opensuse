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
