# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Prepares compatibility layer for using `lib/publiccloud/*` library with SDAF deployment

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

use testapi;
use serial_terminal qw(select_serial_terminal);
use sles4sap::console_redirection qw(connect_target_to_serial disconnect_target_from_serial);
use sles4sap::sap_deployment_automation_framework::inventory_tools qw(read_inventory_file sdaf_create_instances);
use sles4sap::sap_deployment_automation_framework::naming_conventions;

sub run {
    my ($self, $run_args) = @_;
    select_serial_terminal;
    my $workload_vnet_code = get_workload_vnet_code();
    my $sap_sid = get_required_var('SAP_SID');
    my $sdaf_region_short = convert_region_to_short(get_required_var('PUBLIC_CLOUD_REGION'));
    my $sdaf_env_code = get_required_var('SDAF_ENV_CODE');

    my $config_root_path = get_sdaf_config_path(
        deployment_type => 'sap_system',
        env_code => $sdaf_env_code,
        sdaf_region_code => $sdaf_region_short,
        vnet_code => $workload_vnet_code,
        sap_sid => $sap_sid);

    my $inventory_path = get_sdaf_inventory_path(config_root_path => $config_root_path, sap_sid => $sap_sid);
    my $sut_ssh_private_key = get_sut_sshkey_path(config_root_path => $config_root_path);

    # Redirect serial to deployer VM. Deployer VM takes same role as worker VM.
    # Normally PC test runs under root user
    connect_target_to_serial(switch_root => 'yes');

    # PC lib uses 'bernhard' user by default - change global variable to override this default value
    $testapi::username = "root";

    my $inventory_data = read_inventory_file($inventory_path);

    # Copy SUT ssh key to root user home dir which is what PC library is using by default.
    assert_script_run("cp -Rp $sut_ssh_private_key /root/.ssh/id_rsa");
    # Copy known_hosts file from azureadm user
    assert_script_run("cp /home/azureadm/.ssh/known_hosts /root/.ssh/");

    # Create $instances data
    my $instances = sdaf_create_instances(inventory_content => $inventory_data, sut_ssh_key_path => $sut_ssh_private_key);
    $run_args->{instances} = $self->{instances} = $instances;
    publiccloud::instances::set_instances(@$instances);

    # This is required for `lib/sles4sap_publiccloud.pm`
    $run_args->{site_a} = $run_args->{instances}[0];
    $run_args->{site_b} = $run_args->{instances}[1];

    # Basic check if PC library calls work.
    for my $instance (@$instances) {
        $self->{my_instance} = $instance;
        record_info('Wait SSH', 'Running "wait_for_ssh()" on: ' . $instance->{instance_id});
        $instance->update_instance_ip();
        $instance->wait_for_ssh();

        # Check hostname and verify `ssh_script_output` function working
        record_info('hostname check', "Checking expected hostname '$instance->{instance_id}'");
        my $real_hostname = $instance->ssh_script_output(cmd => 'hostname');
        die "Hostname '$real_hostname' returned by server does not match expected one - $instance->{instance_id}" unless
          $real_hostname =~ $instance->{instance_id};

        # Check connected user and verify `ssh_script_run` working
        die 'Check if connected user is "azureadm"' if $instance->ssh_script_run(cmd => 'whoami | grep azureadm');

        # Check system status and test 'ssh_script_run' function
        $instance->ssh_assert_script_run(cmd => 'systemctl is-system-running');

        # Check NTP service and verify 'ssh_assert_script_run' function
        $instance->ssh_assert_script_run(cmd => 'systemctl is-active chronyd');
    }
    disconnect_target_from_serial;
}

1;
