use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use strict;
use testapi;
use mmapi 'get_current_job_id';
use utils 'zypper_call';
use version_utils 'is_sle';
use registration qw(add_suseconnect_product get_addon_fullname);

sub run {
    my ($self, $args) = @_;
    $self->select_serial_terminal;
    my $job_id = get_current_job_id();
    
    my $resource_group = "openqa-cli-test-rg-$job_id";
    my $machine_name = "openqa-cli-test-vm-$job_id";
    my $machine_ip = assert_script_run("az vm show -d -g $resource_group -n $machine_name --query \"publicIps\" -o tsv");
    assert_script_run("curl -k  https://$machine_ip/");

}

sub cleanup {
	my $job_id = get_current_job_id();
	my $resource_group = "openqa-cli-test-rg-$job_id";
	my $machine_name = "openqa-cli-test-vm-$job_id";

	assert_script_run("az group delete --resource-group $resource_group --yes", 180);
}

1;
