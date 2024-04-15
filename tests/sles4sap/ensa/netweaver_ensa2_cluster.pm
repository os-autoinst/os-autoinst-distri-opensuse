# SUSE's SLES4SAP openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Configure cluster resources for ENSA2
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'sles4sap';
use strict;
use warnings;
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils qw(file_content_replace);
use hacluster qw(wait_until_resources_started);
use lockapi;

sub run {
    my ($self) = @_;
    # Set maintenance to 'true'
    assert_script_run("crm configure property maintenance-mode='true'");
    my $instance_type = get_required_var('INSTANCE_TYPE');
    my $install_data = $self->netweaver_installation_data();

    select_serial_terminal;

    barrier_wait('ENSA_CLUSTER_SETUP') unless $instance_type eq 'ASCS';    # All nodes wait for cluster setup on ASCS
    if ($instance_type eq 'ASCS') {
        my $ascs = $install_data->{instances}{ASCS};
        my $ers = $install_data->{instances}{ERS};

        my $hosts_shared_dir = get_required_var('HOSTS_SHARED_DIRECTORY');
        my ($ascs_ip, $ascs_hostname) = split(' ', script_output("cat $hosts_shared_dir/ASCS"));
        my ($ers_ip, $ers_hostname) = split(' ', script_output("cat $hosts_shared_dir/ERS"));

        my $template_file = 'ensa2_cluster_resources.template';
        my $url = autoinst_url . "/data/ha/$template_file";
        my $temp_dir = '/tmp/cluster';
        my %template_variables = (
            '%INSTANCE_SID%' => $install_data->{instance_sid},
            '%INSTANCE_ID_ASCS%' => $ascs->{instance_id},
            '%INSTANCE_ID_ERS%' => $ers->{instance_id},
            '%VIRTUAL_IP_ASCS%' => $ascs_ip,
            '%VIRTUAL_IP_ERS%' => $ers_ip,
            '%VIRTUAL_HOSTNAME_ASCS%' => $ascs_hostname,
            '%VIRTUAL_HOSTNAME_ERS%' => $ers_hostname,
            '%USR_SAP_DEVICE_ASCS%' => get_required_var('USR_SAP_DEVICE_ASCS'),
            '%USR_SAP_DEVICE_ERS%' => get_required_var('USR_SAP_DEVICE_ERS')
        );

        assert_script_run("mkdir -p $temp_dir");
        assert_script_run "curl -f -v $url -o $temp_dir/$template_file";
        file_content_replace("$temp_dir/$template_file", '--sed-modifier' => 'g', %template_variables);

        upload_logs("$temp_dir/$template_file");
        assert_script_run("crm configure load update $temp_dir/$template_file");
        barrier_wait('ENSA_CLUSTER_SETUP');
    }
    assert_script_run("crm configure property maintenance-mode='false'");
    wait_until_resources_started();
    $self->sap_show_status_info(cluster => 1, netweaver => 1,
        instance_id => $install_data->{instances}{$instance_type}{instance_id});
}

1;
