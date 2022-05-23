use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use strict;
use testapi;
use mmapi 'get_current_job_id';

sub run {
    my ($self, $args) = @_;
    $self->select_serial_terminal;
    my $job_id = get_current_job_id();
    
    my $resource_group = "openqa-cli-test-rg-$job_id";
    my $machine_name = "openqa-cli-test-vm-$job_id";
    # Parameter 'registry_name' must conform to the following pattern: '^[a-zA-Z0-9]*$'.
    my $acr_name = "openqaclitestacr$job_id";
    # my $openqa_ttl = get_var('MAX_JOB_TIME', 7200) + get_var('PUBLIC_CLOUD_TTL_OFFSET', 300);
    # my $created_by = get_var('PUBLIC_CLOUD_RESOURCE_NAME', 'openqa-vm');
    # my $tags = "openqa-cli-test-tag=$job_id openqa_created_by=$created_by openqa_ttl=$openqa_ttl";

    # Configure default location and create Resource group
    # assert_script_run("az configure --defaults location=southeastasia");
   
    enter_cmd "cd /root/test";
    ###########################
    # Run the Trento deployment
    my $vm_image = get_var('TRENTO_VM_IMAGE', 'SUSE:sles-sap-15-sp3-byos:gen2:latest');
    my $cmd_00_040 =  "./00.040-trento_vm_server_deploy_azure.sh ".
          "-g $resource_group ".
	  "-s $machine_name ".
	  "-i $vm_image ".
	  "-a cloudadmin ".
	  "-k /root/.ssh/id_rsa.pub ".
	  "-v";
    assert_script_run($cmd_00_040, 360);
   
    my $trento_acr_azure_cmd = "./trento_acr_azure.sh ".
          "-g $resource_group ".
          "-n $acr_name ".
          "-r registry.suse.com/trento/trento-server ".
          "-v";
    assert_script_run($trento_acr_azure_cmd, 360);
    my $machine_ip = script_output("az vm show -d -g $resource_group -n $machine_name --query \"publicIps\" -o tsv");
    my $acr_server = script_output("az acr list -g $resource_group --query \"[0].loginServer\" -o tsv");
    my $acr_username = script_output("az acr credential show -n $acr_name --query username -o tsv");
    my $acr_secret = script_output("az acr credential show -n $acr_name --query 'passwords[0].value' -o tsv");
   
    # Check what registry has been created by  trento_acr_azure_cmd 
    assert_script_run("az acr repository list -n $acr_name");
  
    my $cmd_01_010 = "./01.010-trento_server_installation_premium_v.sh ".
          "-i $machine_ip ".
	  "-k /root/.ssh/id_rsa ".
	  "-u cloudadmin ".
	  "-c 3.8.2 ".
	  '-p $(pwd) '.
	  "-r $acr_server/trento/trento-server ".
	  "-s $acr_username ".
	  '-w $(az acr credential show -n '.$acr_name." --query 'passwords[0].value' -o tsv) ".
	  "-v";
    assert_script_run($cmd_01_010, 600);
}

sub post_fail_hook {
    my ($self) = @_;
    my $job_id = get_current_job_id();
    my $resource_group = "openqa-cli-test-rg-$job_id";
    my $machine_name = "openqa-cli-test-vm-$job_id";

    assert_script_run("az group delete --resource-group $resource_group --yes", 180);
    $self->SUPER::post_fail_hook;
}

1;
