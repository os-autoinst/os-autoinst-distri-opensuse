# SUSE's openQA tests
#
# Copyright 2021-2025 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create VM in Azure using azure-cli binary
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use mmapi 'get_current_job_id';
use utils qw(zypper_call script_retry);
use version_utils 'is_sle';
use registration qw(add_suseconnect_product get_addon_fullname);
use publiccloud::utils qw(calculate_custodian_ttl);

my $silent = (is_sle('>=16')) ? '%silent' : '';

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;
    my $job_id = get_current_job_id();

    # If 'az' is preinstalled, we test that version
    if (script_run("which az") != 0) {
        # Public Cloud module is not needed since SLE 16 to install azure cli
        add_suseconnect_product(get_addon_fullname('pcm'), (is_sle('=12-sp5') ? '12' : undef)) unless (is_sle('16+'));
        add_suseconnect_product(get_addon_fullname('phub')) if (is_sle('=12-sp5') or is_sle('>=16'));
        my $pkgs = (is_sle('>=16')) ? 'az-cli-cmd jq python-susepubliccloudinfo' : 'azure-cli jq python3-susepubliccloudinfo';
        zypper_call("in $pkgs");
    }
    assert_script_run('az version');

    my $provider = $self->provider_factory();

    my $resource_group = "openqa-cli-test-rg-$job_id";
    my $machine_name = "openqa-cli-test-vm-$job_id";

    my $openqa_ttl = get_var('MAX_JOB_TIME', 7200) + get_var('PUBLIC_CLOUD_TTL_OFFSET', 300);
    my $openqa_url = get_var('OPENQA_URL', get_var('OPENQA_HOSTNAME'));
    my $created_by = "$openqa_url/t$job_id";
    my $custodian_ttl = calculate_custodian_ttl($openqa_ttl);
    my $tags = "openqa-cli-test-tag=$job_id openqa_created_by=$created_by openqa_ttl=$openqa_ttl";
    $tags .= " openqa_var_server=$openqa_url openqa_var_job_id=$job_id custodian_ttl=$custodian_ttl";

    # Configure default location
    assert_script_run("az configure --defaults location=southeastasia");

    # Check resource group creation/deletion
    my $temp_rg = "openqa-cli-test-rg-$job_id-check-delete";
    assert_script_run("az group create -n $temp_rg --tags '$tags'");
    assert_script_run("az group delete --resource-group $temp_rg --yes", 360);

    # Create Resource group
    assert_script_run("az group create -n $resource_group --tags '$tags'");

    # Pint - command line tool to query pint.suse.com to get the current image name
    my $image_name = script_output(qq/pint microsoft images --inactive --json | jq -r '[.images[] | select( .urn | contains("sles-15-sp5:gen2") )][0].urn'/);
    die("The pint query output is empty.") unless ($image_name);
    record_info("PINT", "Pint query: " . $image_name);

    # VM creation
    my $vm_create = "az $silent vm create --resource-group $resource_group --name $machine_name --public-ip-sku Standard --tags '$tags'";
    $vm_create .= " --image $image_name --size Standard_B1ms --admin-username azureuser --ssh-key-values ~/.ssh/id_rsa.pub";
    my $output = script_output($vm_create, timeout => 600);
    die('Failed to start/stop vms with azure cli') if ($output =~ /ValidationError.*object has no attribute/);

    assert_script_run("az vm get-instance-view -g $resource_group -n $machine_name");
    assert_script_run("az vm list-ip-addresses -g $resource_group -n $machine_name");

    # Check that the machine is reachable via ssh
    my $ip_address = script_output("az $silent vm list-ip-addresses -g $resource_group -n $machine_name --query '[].virtualMachine.network.publicIpAddresses[0].ipAddress' --output tsv", 90);
    die "IP address not found in output!" unless $ip_address;
    script_retry("ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no azureuser\@$ip_address hostnamectl", 90, delay => 15, retry => 12);
}

sub cleanup {
    my $job_id = get_current_job_id();
    my $resource_group = "openqa-cli-test-rg-$job_id";
    my $machine_name = "openqa-cli-test-vm-$job_id";

    script_run("az group delete --resource-group $resource_group --yes", 360);
    return 1;
}

sub post_run_hook {
    cleanup();
}

sub post_fail_hook {
    cleanup();
}

sub test_flags {
    return {fatal => 0, milestone => 0, always_rollback => 1};
}

1;
