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
    
    # check if VM is still there :-)
    assert_script_run("az vm list -g $resource_group --query \"[].name\"  -o tsv", 180);
    
    my $machine_ip = script_output("az vm show -d -g $resource_group -n $machine_name --query \"publicIps\" -o tsv", 180);

    # test if the web page is reachable on http
    assert_script_run("curl -k  http://" . $machine_ip . "/");

    my $ssh_remote_cmd = "ssh" .
        " -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR" .
        " -i /root/.ssh/id_rsa" .
        " cloudadmin@" . $machine_ip .
        " -- ";
    my $trento_web_password_cmd = $ssh_remote_cmd .
	" kubectl get secret trento-server-web-secret" .
        " -o jsonpath='{.data.ADMIN_PASSWORD}'" .
	"|base64 --decode";
    my $trento_web_password = script_output($trento_web_password_cmd);
    
    my $cypress_log_dir = "/root/result";
    my $cypress_test_dir = "/root/test/test";
    enter_cmd "cd " . $cypress_test_dir;
    assert_script_run("./cypress.env.py -u http://" . $machine_name . " -p " . $trento_web_password);
    enter_cmd "cat cypress.env.json";

    enter_cmd "mkdir " . $cypress_log_dir;
    my $cypress_run_cmd = "podman run -it ".
       "-v $cypress_log_dir:/results ".
       "-v $cypress_test_dir:/e2e -w /e2e ".
       "docker.io/cypress/included:3.4.0";
    enter_cmd $cypress_run_cmd;
    enter_cmd "ls -lai " . $cypress_log_dir;
    enter_cmd "cat $cypress_log_dir/*.xml";

}

sub cleanup {
	my $job_id = get_current_job_id();
	my $resource_group = "openqa-cli-test-rg-$job_id";
	my $machine_name = "openqa-cli-test-vm-$job_id";

	assert_script_run("az group delete --resource-group $resource_group --yes", 180);
}

1;
