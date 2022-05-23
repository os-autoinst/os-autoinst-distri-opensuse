use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use strict;
use testapi;
use mmapi 'get_current_job_id';

use constant CYPRESS_LOG_DIR  => '/root/result';

sub run {
    my ($self, $args) = @_;
    $self->select_serial_terminal;
    my $job_id = get_current_job_id();
    
    my $resource_group = "openqa-cli-test-rg-$job_id";
    my $machine_name = "openqa-cli-test-vm-$job_id";
    
    
    my $machine_ip = script_output("az vm show -d -g $resource_group -n $machine_name --query \"publicIps\" -o tsv", 180);

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
    
    my $cypress_test_dir = "/root/test/test";
    enter_cmd "cd " . $cypress_test_dir;
    assert_script_run("./cypress.env.py -u http://" . $machine_ip . " -p " . $trento_web_password . " -f Premium");
    enter_cmd "cat cypress.env.json";

    assert_script_run "mkdir " . CYPRESS_LOG_DIR;
    my $cypress_ver = get_var('TRENTO_CYPRESS_VERSION', '3.4.0');
    my $cypress_run_cmd = "podman run -it ".
       "-v ".CYPRESS_LOG_DIR.":/results ".
       "-v $cypress_test_dir:/e2e -w /e2e ".
       '-e "DEBUG=cypress:*" '.
       '--entrypoint=\'["/bin/sh", "-c",  "/usr/local/bin/cypress run 2>/results/log.txt"]\' '. 
       'docker.io/cypress/included:'.$cypress_ver.
       ' || echo "Podman exit:$?"';
    assert_script_run($cypress_run_cmd,600);
}

sub post_fail_hook {
    my ($self) = @_;
    my $job_id = get_current_job_id();
    my $resource_group = "openqa-cli-test-rg-$job_id";
    assert_script_run("az group delete --resource-group $resource_group --yes", 600);
    sleep 60;
    script_output('find '.CYPRESS_LOG_DIR.' -type f');
    my $cypress_output = script_output('find '.CYPRESS_LOG_DIR.' -type f |grep -E "\.(xml|mp4|txt|png)"');
    my @cypress_log_files = split(/\n/, $cypress_output);
    upload_logs($_) for @cypress_log_files;

    $self->SUPER::post_fail_hook;
}

1;
