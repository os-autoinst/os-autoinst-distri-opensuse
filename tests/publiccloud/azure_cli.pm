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
use mmapi 'get_current_job_id';
use utils qw(zypper_call script_retry);
use version_utils 'is_sle';
use registration qw(add_suseconnect_product get_addon_fullname);
use publiccloud::utils "select_host_console";

sub run {
    my ($self, $args) = @_;
    $self->select_serial_terminal;
    my $job_id = get_current_job_id();

    # If 'az' is preinstalled, we test that version
    if (script_run("which az") != 0) {
        add_suseconnect_product(get_addon_fullname('pcm'), (is_sle('=12-sp5') ? '12' : undef));
        add_suseconnect_product(get_addon_fullname('phub')) if is_sle('=12-sp5');
        zypper_call('in azure-cli jq python3-susepubliccloudinfo');
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
    my $image_name = script_output("pint microsoft images --active --json | jq -r '.images[] | select( (.urn | contains(\"sles-15-sp3:gen2\")) and (.state == \"active\") and (.environment == \"PublicAzure\")).urn'");
    record_info("PINT", "Pint query: " . $image_name);

    # VM creation
    my $vm_create = "az vm create --resource-group $resource_group --name $machine_name --public-ip-sku Standard --tags '$tags'";
    $vm_create .= " --image $image_name --size Standard_B1ms --admin-username azureuser --ssh-key-values ~/.ssh/id_rsa.pub";
    my $output = script_output($vm_create, timeout => 600, proceed_on_failure => 1);
    if ($output =~ /ValidationError.*object has no attribute/) {
        record_soft_failure('bsc#1191482 - Failed to start/stop vms with azure cli');
        return;
    }

    assert_script_run("az vm get-instance-view -g $resource_group -n $machine_name");
    assert_script_run("az vm list-ip-addresses -g $resource_group -n $machine_name");

    # Check that the machine is reachable via ssh
    my $ip_address = script_output("az vm list-ip-addresses -g $resource_group -n $machine_name --query '[].virtualMachine.network.publicIpAddresses[0].ipAddress' --output tsv", 90);
    script_retry("ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no azureuser\@$ip_address hostnamectl", 90, delay => 15, retry => 12);
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

1;
