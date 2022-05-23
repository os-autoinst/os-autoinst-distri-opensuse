use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use strict;
use testapi;
use mmapi 'get_current_job_id';

use constant TRENTO_AZ_PREFIX  => 'openqa-trento';

sub run {
    my ($self, $args) = @_;
    $self->select_serial_terminal;
    my $job_id = get_current_job_id();
    
    my $resource_group = TRENTO_AZ_PREFIX . "-rg-$job_id";
    my $machine_name = TRENTO_AZ_PREFIX . "-vm-$job_id";
    
    # check if VM is still there :-)
    assert_script_run("az vm list -g $resource_group --query \"[].name\"  -o tsv", 180);
    
    my $machine_ip = script_output("az vm show -d -g $resource_group -n $machine_name --query \"publicIps\" -o tsv", 180);

    # test if the web page is reachable on http
    assert_script_run("curl -k  http://" . $machine_ip . "/");
}

sub post_fail_hook {
    my ($self) = @_;
    my $job_id = get_current_job_id();
    my $resource_group = TRENTO_AZ_PREFIX . "-rg-$job_id";
    assert_script_run("az group delete --resource-group $resource_group --yes", 180);
    $self->SUPER::post_fail_hook;
}

1;
