# SUSE's SLES4SAP openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Executes failover using sapcontrol web methods on ensa2 cluster.
# Requires: sles4sap/netweaver_install, ENV variables INSTANCE_SID, INSTANCE_TYPE and INSTANCE_ID
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'sles4sap';
use testapi;
use hacluster;
use lockapi;
use serial_terminal qw(select_serial_terminal);
use version_utils qw(is_sle);
use sles4sap::sapcontrol;

sub webmethod_checks {
    my ($self, $instance_id,) = @_;
    my $outputs;
    my $looptime = 300;

    # General status will help with troubleshooting
    my $sidadm = $self->get_sidadm();
    sap_show_status_info(cluster => 1, netweaver => 1, instance_id => $instance_id);
    record_info('ENSA check', "Executing 'HACheckConfig' and 'HACheckFailoverConfig'");
    while ($outputs = sapcontrol(webmethod => 'HACheckConfig', instance_id => $instance_id, sidadm => $sidadm, return_output => 1)) {
        last unless ($outputs =~ /ERROR/);
        record_info("ERROR found in HACheckConfig: $outputs", "sleep 30s and try again");
        sleep 30;
        $looptime -= 30;
        last if ($looptime <= 0);
    }
    sapcontrol(webmethod => 'HACheckFailoverConfig', instance_id => $instance_id, sidadm => $sidadm);
}

sub run {
    my ($self) = @_;
    my $sap_sid = get_required_var('INSTANCE_SID');
    my $instance_id_original = get_required_var('INSTANCE_ID');
    my $instance_type_original = get_required_var('INSTANCE_TYPE');
    my $instance_type_remote = $instance_type_original eq 'ASCS' ? 'ERS' : 'ASCS';
    my $physical_hostname = get_required_var('HOSTNAME');
    my $instance_id_remote = get_remote_instance_number(instance_type => $instance_type_remote);
    my $sidadm = $self->get_sidadm();

    select_serial_terminal;

    my $instance_type = $instance_type_original;
    my $instance_id = $instance_id_original;

    # Ensure resource groups are started in correct place (physical hostname)
    die "Resource 'grp_$sap_sid\_$instance_type$instance_id' is not located on $physical_hostname" unless
      crm_check_resource_location(resource => "grp_$sap_sid\_$instance_type$instance_id") eq $physical_hostname;

    $self->webmethod_checks($instance_id);
    # Execute failover from ASCS instance
    if ($instance_type eq 'ASCS') {
        record_info('Failover', "Executing 'HAFailoverToNode'. Failover from $physical_hostname to remote site");
        sapcontrol(webmethod => 'HAFailoverToNode', instance_id => $instance_id, additional_args => "\"\"");
    }

    # After failover, instance type, ID etc is switched.
    $instance_type = $instance_type_remote;
    $instance_id = $instance_id_remote;
    # Wait for failover to finish and check resource locations
    record_info('Failover wait', 'Waiting for failover to complete');
    wait_for_idle_cluster;
    crm_check_resource_location(resource => "grp_$sap_sid\_$instance_type$instance_id", wait_for_target => $physical_hostname);
    barrier_wait('ENSA_FAILOVER_DONE');    # sync nodes

    $self->webmethod_checks($instance_id);
    # Execute failover from ASCS instance - this will return resources to original host
    if ($instance_type eq 'ASCS') {
        # Some delay needed here for 12-SP5, don't know why even webmethod_checks passed
        if (is_sle('=12-SP5')) {
            sleep 300;
            record_info "sleep 300s for 12-SP5";
        }
        record_info('Failback', "Executing 'HAFailoverToNode'. Failover from $physical_hostname to remote site");
        sapcontrol(webmethod => 'HAFailoverToNode', instance_id => $instance_id, sidadm => $sidadm,
            additional_args => "\"\"");
    }

    # After failover, instance type, ID etc is switched.
    $instance_type = $instance_type_original;
    $instance_id = $instance_id_original;

    # Wait for failover to finish and check resource locations
    record_info('Failback wait', 'Waiting for failover to complete');
    wait_for_idle_cluster;
    crm_check_resource_location(resource => "grp_$sap_sid\_$instance_type$instance_id", wait_for_target => $physical_hostname, timeout => 360);
    barrier_wait('ENSA_ORIGINAL_STATE');    # sync nodes
                                            # Final checks
    $self->webmethod_checks($instance_id);
}

1;
