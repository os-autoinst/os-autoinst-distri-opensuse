# SUSE's SLES4SAP openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Configure cluster connector for ENSA2.
# Test module is expected to be run after Netweaver installation process finished and
# at least simple cluster being set up. (Test handles maintenance mode via crm shell)
# Execute this only on ASCS or ERS instance.
#
# Maintainer: QE-SAP <qe-sap@suse.de>

use strict;
use warnings;
use base 'sles4sap';
use testapi;
use hacluster;
use serial_terminal qw(select_serial_terminal);
use utils qw(file_content_replace);
use lockapi;

sub run {
    my ($self) = @_;
    my $sap_sid = get_required_var('INSTANCE_SID');
    my $physical_hostname = get_required_var('HOSTNAME');
    my $nw_install_data = $self->netweaver_installation_data();
    my $instance_type = get_required_var('INSTANCE_TYPE');
    my $instance_id = $nw_install_data->{instances}{$instance_type}{instance_id};
    my $sidadm = $self->get_sidadm(must_exist => 1);

    select_serial_terminal;
    assert_script_run("usermod -a -G haclient $sidadm");

    if ($instance_type eq 'ASCS') {
        my $profile_path_ascs = $self->get_instance_profile_path(instance_id => $instance_id, instance_type => 'ASCS');
        my $instance_id_ers = $self->get_remote_instance_number(instance_type => 'ERS');
        my $profile_path_ers = $self->get_instance_profile_path(instance_type => 'ERS', instance_id => $instance_id_ers);

        record_info('SAP params', 'Changing SAP instance parameters required for cluster connector');
        assert_script_run("crm configure property maintenance-mode='true'");
        crm_wait_for_maintenance(target_state => 'true');

        foreach ($profile_path_ascs, $profile_path_ers) {
            assert_script_run("echo 'service/halib = \$(DIR_EXECUTABLE)/saphascriptco.so' >> $_");
            assert_script_run("echo 'service/halib_cluster_connector = /usr/bin/sap_suse_cluster_connector' >> $_");
            # Disable autostart
            file_content_replace($_, 'Autostart = 1', 'Autostart = 0');
        }

        # Disable service restart
        file_content_replace($profile_path_ascs, 'Restart_Program_01 = local $(_ENQ)', 'Start_Program_01 = local $(_ENQ)');
        file_content_replace($profile_path_ers, 'Restart_Program_00 = local $(_ER)', 'Start_Program_00 = local $(_ER)');
    }

    barrier_wait('ENSA_CLUSTER_CONNECTOR_SETUP_DONE');

    # Restart instances to apply parameter values
    record_info('SAP restart', 'Restarting ASCS and ERS to apply parameters');
    $self->sapcontrol(webmethod => 'StopService', instance_id => $instance_id);
    $self->sapcontrol_process_check(expected_state => 'failed', wait_for_state => 1);    # After stop service sapcontrol returns RC1 (NIECONN_REFUSED)
    $self->sapcontrol(webmethod => 'StartService', additional_args => $sap_sid, instance_id => $instance_id);
    $self->sapcontrol_process_check(expected_state => 'started', wait_for_state => 1);

    assert_script_run("crm configure property maintenance-mode='false'");
    crm_wait_for_maintenance(target_state => 'false');

    # Ensure resource groups are started in correct place (physical hostname)
    crm_check_resource_location(resource => "grp_$sap_sid\_$instance_type$instance_id", wait_for_target => $physical_hostname);
    $self->sap_show_status_info(cluster => 1, netweaver => 1,
        instance_id => $instance_id);
}

1;
