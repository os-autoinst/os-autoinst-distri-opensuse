# SUSE's SLES4SAP openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: crmsh
# Summary: Configure NetWeaver cluster
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.de>

use base "sles4sap";
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use hacluster;
use utils 'systemctl';
use strict;
use warnings;

sub run {
    my ($self) = @_;
    my $instance_id = get_required_var('INSTANCE_ID');
    my $type = get_required_var('INSTANCE_TYPE');
    my $sid = get_required_var('INSTANCE_SID');
    my $alias = get_required_var('INSTANCE_ALIAS');
    my $lun = get_required_var('INSTANCE_LUN');
    my $cluster_name = get_cluster_name;
    my ($ip, $netmask) = split '/', get_required_var('INSTANCE_IP_CIDR');

    # Set SAP variables
    my $pscmd = $self->set_ps_cmd("$type");
    my $sapadm = $self->set_sap_info($sid, $instance_id);

    # Synchronize the nodes
    barrier_wait "NW_CLUSTER_INSTALL_$cluster_name";

    select_serial_terminal;

    # Stop the NW instance to add it in the cluster stack
    $self->user_change;
    $self->test_version_info;
    $self->test_instance_properties;
    $self->test_stop;

    # Disconnect SAP account
    $self->reset_user_change;

    # Some file changes are needed for HA
    select_serial_terminal;

    my $profile_file = "/usr/sap/$sid/SYS/profile/${sid}_${type}${instance_id}_${alias}";

    assert_script_run 'cp /sapinst/sapservices /usr/sap/';
    assert_script_run "echo 'service/halib = \${DIR_CT_RUN}/saphascriptco.so' >> $profile_file";
    assert_script_run "echo 'service/halib_cluster_connector = /usr/bin/sap_suse_cluster_connector' >> $profile_file";
    assert_script_run "sed -i 's/^Restart_Program_\\(.*[[:blank:]]*=\\)/Start_Program_\\1/' $profile_file";

    # Add SAP account into haclient group
    assert_script_run "usermod -a -G haclient $sapadm";

    # Removed uneeded(?) profile directory for ERS
    if ($type eq 'ERS') {
        assert_script_run "rm -rf /usr/sap/$sid/${type}${instance_id}/profile";
        assert_script_run "ln -s /sapmnt/$sid/profile /usr/sap/$sid/${type}${instance_id}/profile";
        assert_script_run "chown -h ha1adm:sapsys /usr/sap/$sid/${type}${instance_id}/profile";
    }

    # Create the resource configuration
    my @sedoptions = undef;
    push @sedoptions, "-e 's|%SID%|$sid|g'";
    push @sedoptions, "-e 's|%${type}_INSTANCE%|$instance_id|g'";
    push @sedoptions, "-e 's|%${type}_ALIAS%|$alias|g'";
    push @sedoptions, "-e 's|%${type}_LUN%|$lun|g'";
    push @sedoptions, "-e 's|%${type}_IP%|$ip|g'";

    # We need to execute the sed command node by node
    my $cmd = undef;
    my $nw_cluster_conf = '/sapmnt/nw_cluster.conf';
    if (is_node(1)) {
        # Initiate the template
        $cmd = 'sed' . join(' ', @sedoptions) . " /sapinst/nw_cluster.conf > $nw_cluster_conf";
        assert_script_run $cmd;

        # Synchronize the nodes
        barrier_wait "NW_INIT_CONF_$cluster_name";
        barrier_wait "NW_CREATED_CONF_$cluster_name";

        # Upload the configuration into the cluster
        assert_script_run 'crm configure property maintenance-mode=true';
        assert_script_run "crm configure load update $nw_cluster_conf";
        assert_script_run 'crm configure property maintenance-mode=false';
    }
    else {
        # Synchronize the nodes
        barrier_wait "NW_INIT_CONF_$cluster_name";

        # Use mutex to be sure that only *one* node at a time can access the file
        mutex_lock 'support_server_ready';

        # Modify the template
        $cmd = 'sed -i' . join(' ', @sedoptions) . " $nw_cluster_conf";
        assert_script_run $cmd;

        # Release the lock and synchronize the nodes
        mutex_unlock 'support_server_ready';

        # Synchronize the nodes
        barrier_wait "NW_CREATED_CONF_$cluster_name";
    }

    # Synchronize the nodes
    barrier_wait "NW_LOADED_CONF_$cluster_name";

    # Wait for resources to be started
    wait_until_resources_started(timeout => 300);

    # And check for the state of the whole cluster
    check_cluster_state;
}

1;
