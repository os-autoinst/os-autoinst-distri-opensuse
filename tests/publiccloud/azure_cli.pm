# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create VM in Azure using azure-cli binary
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use mmapi 'get_current_job_id';
use utils qw(zypper_call script_retry);
use version_utils 'is_sle';
use registration qw(add_suseconnect_product get_addon_fullname);
use strict;
use warnings;
use publiccloud::utils;

our $azure_repo = get_required_var('PY_AZURE_REPO');
our $backports_repo = get_required_var('PY_BACKPORTS_REPO');
our $cloud_tools_repo = get_required_var('CLOUD_TOOLS_REPO');

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;
    my $job_id = get_current_job_id();


    # if cloud_tools and azure repo is provided create sles vm and validate azure cli test 
    if (exists($azure_repo) && exists($backports_repo) && ($cloud_tools_repo)) {
        create_vm($azure_repo,$backports_repo,$cloud_tools_repo);
    }

    # If 'az' is preinstalled, we test that version
    if (script_run("which az") != 0) {
        add_suseconnect_product(get_addon_fullname('pcm'), (is_sle('=12-sp5') ? '12' : undef));
        add_suseconnect_product(get_addon_fullname('phub')) if is_sle('=12-sp5');
        # bsc#1201870c1 - please remove python3-azure-mgmt-resource
        zypper_call('in azure-cli jq python3-susepubliccloudinfo python3-azure-mgmt-resource');
    }
    assert_script_run('az version');

    set_var 'PUBLIC_CLOUD_PROVIDER' => 'AZURE';
    my $provider = $self->provider_factory();

    my $resource_group = "openqa-cli-test-rg-$job_id";
    my $machine_name = "openqa-cli-test-vm-$job_id";

    my $openqa_ttl = get_var('MAX_JOB_TIME', 7200) + get_var('PUBLIC_CLOUD_TTL_OFFSET', 300);
    my $created_by = get_var('PUBLIC_CLOUD_RESOURCE_NAME', 'openqa-vm');
    my $tags = "openqa-cli-test-tag=$job_id openqa_created_by=$created_by openqa_ttl=$openqa_ttl";

    # Configure default location and create Resource group
    assert_script_run("az configure --defaults location=southeastasia");
    assert_script_run("az group create -n $resource_group --tags '$tags'");

    # Pint - command line tool to query pint.suse.com to get the current image name
    my $image_name = script_output(qq/pint microsoft images --active --json | jq -r '[.images[] | select( .urn | contains("sles-15-sp4:gen2") )][0].urn'/);
    die("The pint query output is empty.") unless ($image_name);
    record_info("PINT", "Pint query: " . $image_name);

    # VM creation
    my $vm_create = "az vm create --resource-group $resource_group --name $machine_name --public-ip-sku Standard --tags '$tags'";
    $vm_create .= " --image $image_name --size Standard_B1ms --admin-username azureuser --ssh-key-values ~/.ssh/id_rsa.pub";
    my $output = script_output($vm_create, timeout => 600);
    if ($output =~ /ValidationError.*object has no attribute/) {
        record_soft_failure('bsc#1191482 - Failed to start/stop vms with azure cli');
        return;
    }

    assert_script_run("az vm get-instance-view -g $resource_group -n $machine_name");
    assert_script_run("az vm list-ip-addresses -g $resource_group -n $machine_name");

    # Check that the machine is reachable via ssh
    my $ip_address = script_output("az vm list-ip-addresses -g $resource_group -n $machine_name --query '[].virtualMachine.network.publicIpAddresses[0].ipAddress' --output tsv", 90);
    script_retry("ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no azureuser\@$ip_address hostnamectl", 90, delay => 15, retry => 12);

    my $location = "southeastasia";
    my $sshkey = "~/.ssh/id_rsa.pub";
    # Call Virtual Network and Run Command Test
    virtual_network_test($resource_group,$location,$machine_name,$sshkey,$image_name);
    run_cmd_test($resource_group,$location,$machine_name,$sshkey,$image_name);
    vmss_test($resource_group,$location,$machine_name,$sshkey,$image_name);
}

sub cleanup {
    my $job_id = get_current_job_id();
    my $resource_group = "openqa-cli-test-rg-$job_id";
    my $machine_name = "openqa-cli-test-vm-$job_id";

    assert_script_run("az group delete --resource-group $resource_group --yes", 180);
}

sub test_flags {
    return {fatal => 0, milestone => 0, always_rollback => 1};
}

sub virtual_network_test {
    my ($rg,$loc,$mn,$ssh,$img) = @_;
    assert_script_run("cd $root_dir");
    assert_script_run('curl ' . data_url('publiccloud/azure_vn.sh') . ' -o azure_vn.sh');
    assert_script_run('chmod +x azure_vn.sh');
    my $start_cmd = $root_dir . '/azure_vn.sh $rg, $loc, $mn, $ssh, $img start ' . $self->instance_log_args();
    assert_script_run($start_cmd);
}

sub run_cmd_test {
    my ($rg,$loc,$mn,$ssh,$img) = @_;
    assert_script_run("cd $root_dir");
    assert_script_run('curl ' . data_url('publiccloud/azure_runcmd.sh') . ' -o azure_runcmd.sh');
    assert_script_run('chmod +x azure_runcmd.sh');
    my $start_cmd = $root_dir . '/azure_runcmd.sh $rg, $loc, $mn, $ssh, $img start ' . $self->instance_log_args();
    assert_script_run($start_cmd);
}

sub vmss_test {
    my ($rg,$loc,$mn,$ssh,$img) = @_;
    assert_script_run("cd $root_dir");
    assert_script_run('curl ' . data_url('publiccloud/azure_vmss.sh') . ' -o azure_vmss.sh');
    assert_script_run('chmod +x azure_vmss.sh');
    my $start_cmd = $root_dir . '/azure_vmss.sh $rg, $loc, $mn, $ssh, $img start ' . $self->instance_log_args();
    assert_script_run($start_cmd);
}

sub create_vm {
    my ($ar,$br,$ctr) = @_;

    select_serial_terminal();
    my $provider = $args->{my_provider};
    my $instance = $provider->create_instance();
    $instance->wait_for_guestregister();
    registercloudguest($instance) if is_byos();

    # call addons for pcm and phub
    # register module-public-cloud and PackageHub
    register_addons_in_pc($instance);

    #Add Repos and install azure-cli
    $instance->run_ssh_command(cmd => 'sudo zypper -n addrepo -fG ' . $ar, timeout => 600);
    $instance->run_ssh_command(cmd => 'sudo zypper -n addrepo -fG ' . $br, timeout => 600);
    $instance->run_ssh_command(cmd => 'sudo zypper -n addrepo -fG ' . $ctr, timeout => 600);
    $instance->ssh_assert_script_run('sudo zypper ref; sudo zypper -n up', timeout => 300);
    $instance->ssh_assert_script_run('sudo zypper install --allow-vendor-change --force azure-cli', timeout => 300);

    record_info('azure cli installed');

    sleep 90;    # wait for a bit for zypper to be available
}
1;
