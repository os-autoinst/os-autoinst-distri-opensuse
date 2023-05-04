# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Azure VM CLI test
#
#   This test does the following
#    - Create AZURE VM and test azure cli tests
#
# Maintainer: Yogalakshmi Arunachalam <yarunachalam@suse.com>

use publiccloud::azure_client;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use mmapi 'get_current_job_id';
use strict;
use warnings;
use utils;
use publiccloud::utils;
use Data::Dumper;

has subscription => sub { get_var('PUBLIC_CLOUD_AZURE_SUBSCRIPTION_ID') };
has region => sub { get_var('PUBLIC_CLOUD_REGION', 'westeurope') };
has username => sub { get_var('PUBLIC_CLOUD_USER', 'azureuser') };

our $root_dir = '/home/azureuser';

sub run {
    my ($self, $args) = @_;
    select_serial_terminal();
    my $job_id = get_current_job_id();
    my @test_scripts = ("azure_lib_fn.sh");
    #my $include_tests = "azure_lib_fn.sh";
    my @tests = split(',',get_var('AZURE_CLI_TEST_NAME')); 
    #possible value for AZURE_CLI_TEST_NAME is vn,vmss,runcmd,rbac,arm_grp,arm_sub,arm_mg,lb
    foreach my $t (@tests)
    { 
      if("$t" eq "vn") {
         push(@test_scripts,"azure_vn.sh");
      }elsif("$t" eq "vmss") {
         push(@test_scripts,"azure_vmss.sh");
      }elsif("$t" eq "runcmd") {
         push(@test_scripts,"azure_runcmd.sh");
      }elsif("$t" eq "rbac") {
         push(@test_scripts,"azure_rbac.sh");
      }elsif("$t" eq "arm_grp") {
         push(@test_scripts,"azure_arm_grp.sh");
      }elsif("$t" eq "arm_sub") {
         push(@test_scripts,"azure_arm_sub.sh");
      }elsif("$t" eq "arm_mg") {
         push(@test_scripts,"azure_arm_mg.sh");
      }elsif("$t" eq "lb") {
         push(@test_scripts,"azure_lb.sh");
      }
      print "included tests".Dumper(@test_scripts);
    }

    #Create Azure vm
    my $provider = $args->{my_provider};
    my $instance = $provider->create_instance();
    $instance->wait_for_guestregister();
    registercloudguest($instance) if is_byos();
    set_var('SCC_ADDONS', "base,serverapp");
    register_addons_in_pc($instance);
    $instance->ssh_assert_script_run('sudo SUSEConnect -list-extensions', timeout => 300);
    $instance->ssh_assert_script_run('sudo SUSEConnect -p sle-module-public-cloud/15.4/x86_64', timeout => 300);

    #Install required repo and azure cli
    $instance->ssh_assert_script_run('sudo zypper ref; sudo zypper -n up', timeout => 900);
    my $azure_repo = get_required_var('PY_AZURE_REPO');
    my $backports_repo = get_required_var('PY_BACKPORTS_REPO');
    my $cloud_tools_repo = get_required_var('CLOUD_TOOLS_REPO');
    $instance->run_ssh_command(cmd => 'cat /etc/os-release; sudo zypper -n addrepo -fG ' . $azure_repo, timeout => 600);
    $instance->run_ssh_command(cmd => 'sudo zypper -n addrepo -fG ' . $backports_repo, timeout => 600);
    $instance->run_ssh_command(cmd => 'sudo zypper -n addrepo -fG ' . $cloud_tools_repo, timeout => 600);
    $instance->ssh_assert_script_run('sudo zypper ref; sudo zypper -n up', timeout => 300);
    $instance->ssh_assert_script_run('sudo zypper in -y --allow-vendor-change --force azure-cli', timeout => 1600);
    record_info('azure cli installed');

    #Configure defaul location and create Resource Group
    my $resource_group = "avmclirg$job_id";
    my $machine_name = "avmclivm$job_id";
    my $openqa_ttl = get_var('MAX_JOB_TIME', 7200) + get_var('PUBLIC_CLOUD_TTL_OFFSET', 300);
    my $created_by = get_var('PUBLIC_CLOUD_RESOURCE_NAME', 'openqa-vm');
    my $tags = "avmclitag=$job_id openqa_created_by=$created_by openqa_ttl=$openqa_ttl";
    my $location ="southeastasia";
    my $sshkey = "~/.ssh/id_rsa.pub";
    my $subid = $instance->provider->provider_client->subscription;
    record_info('subid ',$subid);

    #Initialize AZ
    $instance->provider->init();
    record_info('provider init completed');
    $instance->ssh_assert_script_run("az configure --defaults location=$location");
    $instance->ssh_assert_script_run("az group create -n $resource_group --tags '$tags'", timeout => 900);
    record_info('Resource Group Created',$resource_group);


    # Pint - command line tool to query pint.suse.com to get the current image name
    my $image_name = script_output(qq/pint microsoft images --active --json | jq -r '[.images[] | select( .urn | contains("sles-15-sp4:gen2") )][0].urn'/);
    die("The pint query output is empty.") unless ($image_name);
    record_info("PINT", "Pint query: " . $image_name);

    # Call Virtual Network ,Run Command and Virtual Machine Scale Set Test
    load_cli_test($resource_group,$location,$machine_name,$sshkey,$image_name,$subid,@test_scripts);

    sub load_cli_test {
    my ($rg,$loc,$mn,$ssh,$img,$sub_id,@cli_tests) = @_;
    #for each test it scp the test scripts and dependency scripts and execute the test
    foreach my $test_name (@cli_tests) {
       if ($instance->ssh_script_output(cmd => "ls $root_dir/$test_name | wc -l") == 0) {
           record_info('Preparing permission for cli test ',$test_name);
           assert_script_run("curl " . data_url("publiccloud/$test_name") . " -o /tmp/$test_name", 60);
	   $instance->scp( "/tmp/$test_name", 'remote:' . "$root_dir/$test_name", 200 );
           $instance->run_ssh_command(cmd => "chmod +x $root_dir/$test_name", timeout => 60);
	   my $dep_test_name="N/A"
           if ($test_name eq "azure_rbac.sh"){
              my $dep_test_name = "rbac.config" 
           } elsif ($test_name eq "azure_arm_grp.sh") {  
              my $dep_test_name = "azure_arm_grp_template.json" 
           } elsif ($test_name eq "azure_arm_sub.sh") {
              my $dep_test_name = "azure_arm_sub_template.json" 
           } elsif ($test_name eq "azure_arm_mg.sh") {
              my $dep_test_name = "azure_arm_mg_template.json" 
           }
           if ($dep_test_name ne "N/A"){
	       record_info('Preparing permission for cli test ',$dep_test_name);
               assert_script_run("curl " . data_url("publiccloud/$dep_test_name") . " -o /tmp/$dep_test_name", 60);
               $instance->scp( "/tmp/$test_name", 'remote:' . "$root_dir/$dep_test_name", 200 );
               $instance->run_ssh_command(cmd => "chmod +x $root_dir/$dep_test_name", timeout => 60);
           }
       }
       if ($test_name ne "azure_lib_fn.sh") {
           record_info('Ready to run cli test ',$test_name);
           my $start_cmd = $root_dir . "/$test_name $rg $loc $mn $ssh $img $sub_id";
           my $script_output = $instance->run_ssh_command(cmd => "$start_cmd", timeout => 3000, proceed_on_failure => 1);
       }
    }
    return;
    }

    sub cleanup {
    my $cjob_id = get_current_job_id();
    my $rs_group = "openqa-cli-test-rg-$cjob_id";
    my $mc_name = "openqa-cli-test-vm-$cjob_id";

    assert_script_run("az group delete --resource-group $resource_group --yes", 180);
    }

    sub test_flags {
    return {fatal => 0, milestone => 0, always_rollback => 1};
    }
}

1;
