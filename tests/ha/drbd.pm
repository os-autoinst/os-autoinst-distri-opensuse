# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: DRBD OpenQA test
# Create DRBD device
# Create crm ressource
# Check resource migration
# Check multistate status
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'hacluster';
use strict;
use testapi;
use autotest;
use lockapi;

sub run {
    my $self = shift;

    # 2 LUN are needed for DRBD
    my $drbd_lun_01 = script_output "realpath -ePL /dev/disk/by-path/ip-*-lun-4";
    my $drbd_lun_02 = script_output "realpath -ePL /dev/disk/by-path/ip-*-lun-5";

    # DRBD needs 2 nodes for the test, so we can easily
    # arbitrary choose the first two
    my $node_01    = $self->choose_node(1);
    my $node_02    = $self->choose_node(2);
    my $node_01_ip = script_output 'host -t A ' . $node_01 . ' | awk \'{ print $NF }\'';
    my $node_02_ip = script_output 'host -t A ' . $node_02 . ' | awk \'{ print $NF }\'';

    # Wait until DRBD test is initialized
    barrier_wait('DRBD_INIT_' . $self->cluster_name);

    # Modify DRBD global configuration file
    assert_script_run 'sed -i \'/^[[:blank:]]*startup[[:blank:]]*{/a \\\t\twfc-timeout 100;\n\t\tdegr-wfc-timeout 120;\' /etc/drbd.d/global_common.conf';

    # Get resource configuration template from the openQA server
    assert_script_run 'curl -f -v ' . autoinst_url . '/data/ha/drbd-r0.res.template -o /etc/drbd.d/r0.res';

    # And modify the template according to our needs
    assert_script_run "sed -i 's/%NODE_01%/$node_01/g' /etc/drbd.d/r0.res";
    assert_script_run "sed -i 's/%NODE_02%/$node_02/g' /etc/drbd.d/r0.res";
    assert_script_run "sed -i 's/%ADDR_NODE_01%/$node_01_ip/g' /etc/drbd.d/r0.res";
    assert_script_run "sed -i 's/%ADDR_NODE_02%/$node_02_ip/g' /etc/drbd.d/r0.res";

    # Note: we use ';' instead of '/' as the sed separator because of UNIX file names
    assert_script_run "sed -i 's;%DRBD_LUN_01%;$drbd_lun_01;g' /etc/drbd.d/r0.res";
    assert_script_run "sed -i 's;%DRBD_LUN_02%;$drbd_lun_02;g' /etc/drbd.d/r0.res";

    # Show the result
    type_string "cat /etc/drbd.d/r0.res\n";

    # Create the DRBD device
    assert_script_run 'drbdadm create-md r0';
    assert_script_run 'drbdadm up r0';

    # Wait for first node to complete its configuration
    barrier_wait('DRBD_CREATE_DEVICE_NODE_01_' . $self->cluster_name);

    # Configure first node as a primary node
    if ($self->is_node(1)) {
        assert_script_run 'drbdadm primary --force r0';
        assert_script_run 'drbdadm status r0';

        # Run assert_script_run timeout 240 during the long assert_script_run drbd sync
        assert_script_run 'while ! $(drbdadm status r0 | grep -q "peer-disk:UpToDate"); do sleep 10; drbdadm status r0; done', 240;
    }
    else {
        diag 'Wait until drbd device is created on first node...';
    }

    # Wait for second node to complete its configuration
    barrier_wait('DRBD_CHECK_DEVICE_NODE_02_' . $self->cluster_name);

    # Configure second node as a slave node
    if ($self->is_node(2)) {
        assert_script_run 'drbdadm status r0';

        # Run assert_script_run timeout 240 during the long assert_script_run drbd sync
        assert_script_run 'while ! $(drbdadm status r0 | grep -q "peer-disk:UpToDate"); do sleep 10; drbdadm status r0; done', 240;
    }
    else {
        diag 'Wait until drbd status is set...';
    }

    # Wait for DRBD HA setup to complete
    barrier_wait('DRBD_SETUP_DONE_' . $self->cluster_name);

    # This "simple" code is here to stop DRBD before restarting it with Pacemaker
    # For a unknown reason, it doesn't work with openQA (it works inside a VM out of openQA)
    # Keep it for now, as it runs as-is, but we should correct this later!
    #
    # Force first node to wait a little before stopping DRBD device
    # Because if we try to stop on both node at the same time it failed!
    # if ($self->is_node(1)) {
    #     sleep 10;
    # }
    #
    # Stop DRBD device before configuring Pacemaker
    # DRBD need to be started by Pacemaker!
    # assert_script_run 'drbdadm down r0';
    #
    # Wait for DRBD device to stop
    # barrier_wait('DRBD_DOWN_DONE_' . $self->cluster_name);

    # Create the HA resource
    if ($self->is_node(1)) {
        assert_script_run
'EDITOR="sed -ie \'$ a primitive drbd ocf:linbit:drbd params drbd_resource=r0 drbdconf=/etc/drbd.conf op start timeout=240 op stop timeout=100 op monitor interval=29 role=Master op monitor interval=31 role=Slave\'" crm configure edit';
        assert_script_run
          'EDITOR="sed -ie \'$ a ms ms-drbd drbd meta master-max=1 master-node-max=1 clone-max=2 clone-node-max=1 notify=true\'" crm configure edit';

        # Just to be sure that Pacemaker has done its job!
        sleep 10;

        # Sometimes we need to cleanup the resource
        assert_script_run 'crm resource cleanup drbd';

        # Wait to get DRBD running on all nodes
        # This sleep value needs to be the same as the resource start timeout (currently 240s)
        diag 'Wait until drbd resource is created/activated...';
        sleep 240;

        # Check for result
        assert_script_run "crm resource status ms-drbd | grep ':[[:blank:]]*$node_01\[[:blank:]]*[Mm]aster\$'";
    }
    else {
        diag 'Wait until drbd resource is created/activated...';
    }

    # Wait for DRBD to be checked
    barrier_wait("DRBD_RES_CREATED_" . $self->cluster_name);

    # Migrate DRBD resource on the second node
    if ($self->is_node(2)) {
        assert_script_run "crm resource migrate ms-drbd $node_02";

        # Check the migration / timeout 240 sec it takes some time to update
        assert_script_run 'while ! $(drbdadm status r0 | grep -q "r0 role:Primary"); do sleep 10; drbdadm status r0; done', 240;

        # Check for result
        assert_script_run "crm resource status ms-drbd | grep ':[[:blank:]]*$node_02\[[:blank:]]*[Mm]aster\$'";
    }

    # Wait for DRBD resrouce migration to be done
    barrier_wait('DRBD_MIGRATION_DONE_' . $self->cluster_name);

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
