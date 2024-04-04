# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
#
# Library used for Microsoft SDAF deployment

package sles4sap::sdaf_library;

use strict;
use warnings;
use testapi;
use Exporter qw(import);
use Carp qw(croak);
use mmapi qw(get_current_job_id);
use utils qw(write_sut_file);
use File::Basename;
use Regexp::Common qw(net);

=head1 SYNOPSIS

Library with common functions for Microsoft SDAF deployment automation. Documentation can be found on the
L<projects official website|https://learn.microsoft.com/en-us/azure/sap/automation/get-started>

Github repositories:
L<Automation scripts|https://github.com/Azure/sap-automation/tree/main>
L<Sample configurations|https://github.com/Azure/SAP-automation-samples/tree/main>

Basic terminology:

B<SDAF>: SAP deployment automation framework

B<Control plane>: Common term for Resource groups B<Deployer> and B<Library>.
Generally it is part of a permanent infrastructure in the cloud.

B<Deployer>: Resource group providing services such as keyvault, Deployer VM and associated resources.

B<Deployer VM>: Central point that contains SDAF installation and where the deployment is executed from.
Since SUT VMs have no public IPs, this is also serving as a jumphost to reach them via SSH.

B<Library>: Resource group providing storage for terraform state files, SAP media and private DNS zone.

B<Workload zone>: Resource group that provides services similar to support server.

B<SAP Systems>: Resource group containing SAP SUTs and related resources.

=cut

our @EXPORT = qw(
  az_login
  sdaf_prepare_ssh_keys
  sdaf_get_deployer_ip
  serial_console_diag_banner
  set_common_sdaf_os_env
  prepare_sdaf_repo
  cleanup_sdaf_files
);


=head2 homedir

    homedir();

Returns home directory path for current user from env variable $HOME.

=cut

sub homedir {
    return (script_output('echo $HOME'));
}

=head2 deployment_dir

    deployment_dir([create=>1]);

B<create>: Create directory if it does not exist.

Returns deployment directory path with job ID appended as unique identifier.
Optionally it can create directory if it does not exists.

=cut

sub deployment_dir {
    my (%args) = @_;
    my $deployment_dir = get_var('DEPLOYMENT_ROOT_DIR', '/tmp') . '/Azure_SAP_Automated_Deployment_' . get_current_job_id();
    assert_script_run("mkdir -p $deployment_dir") if $args{create};
    return $deployment_dir;
}

=head2 log_dir

    log_dir([create=>1]);

B<create>: Create directory if it does not exist.

Returns logging directory path with job ID appended as unique identifier.
Optionally creates the directory.

=cut

sub log_dir {
    my (%args) = @_;
    my $log_dir = deployment_dir() . '/openqa_logs';
    assert_script_run("mkdir -p $log_dir") if $args{create};
    return $log_dir;
}

=head2 variable_file

    variable_file();

Returns full path to a file containing all required SDAF OS env variables.
Sourcing this file is essential for running SDAF.

=cut

sub variable_file {
    return deployment_dir() . '/sdaf_variables';
}



=head2 az_login

 az_login();

Logins into azure account using SPN credentials. Those are not typed directly into the command but using OS env variables.
To avoid exposure of credentials in serial console, there is a special temporary file used which contains required variables.

SPN credentials are defined by secret OpenQA parameters:

B<_SECRET_AZURE_SDAF_APP_ID>

B<_SECRET_AZURE_SDAF_APP_PASSWORD>

B<_SECRET_AZURE_SDAF_TENANT_ID>

SDAF needs SPN credentials with special permissions. Check link below for details.
https://learn.microsoft.com/en-us/azure/sap/automation/deploy-control-plane?tabs=linux#prepare-the-deployment-credentials

=cut

sub az_login {
    # SDAF tests execute on same jump VM, therefore each file needs unique ID
    my $temp_file = '/tmp/az_login_' . get_current_job_id();
    my @variables = (
        'export ARM_CLIENT_ID=' . get_required_var('_SECRET_AZURE_SDAF_APP_ID'),
        'export ARM_CLIENT_SECRET=' . get_required_var('_SECRET_AZURE_SDAF_APP_PASSWORD'),
        'export ARM_TENANT_ID=' . get_required_var('_SECRET_AZURE_SDAF_TENANT_ID'),
    );

    # Write variables into temporary file using openQA infrastructure to avoid exposing variable values.
    write_sut_file($temp_file, join("\n", @variables));
    # Source file and load variables
    assert_script_run("source $temp_file");

    my $login_cmd = 'while ! az login --service-principal -u ${ARM_CLIENT_ID} -p ${ARM_CLIENT_SECRET} -t ${ARM_TENANT_ID}; do sleep 10; done';
    assert_script_run($login_cmd, timeout => 5 * 60);

    my $subscription_id = script_output('az account show -o tsv --query id');
    record_info('AZ login', "Subscription id: $subscription_id");

    # Remove temp file with credentials.
    assert_script_run("rm $temp_file");
    return ($subscription_id);
}

=head2 create_sdaf_os_var_file

    create_sdaf_os_var_file($entries);

B<$entries>: ARRAYREF of entries to be appended to variable source file

Creates a simple file with bash env variables and uploads it to the target host without revealing content in serial console.
File is sourced afterwards.
For detailed variable description check : L<https://learn.microsoft.com/en-us/azure/sap/automation/naming>

=cut

sub create_sdaf_os_var_file {
    my ($entries) = @_;
    croak 'Expected an ARRAYREF but got: ' . ref $entries if (ref $entries ne 'ARRAY');

    write_sut_file(variable_file, join("\n", @$entries));
    assert_script_run('source ' . variable_file, quiet => 1);
}

=head2 sdaf_get_deployer_ip

    sdaf_get_deployer_ip(deployer_resource_group=>$deployer_resource_group);

B<deployer_resource_group>: Deployer key vault name

Retrieves public IP of the deployer VM.

=cut

sub sdaf_get_deployer_ip {
    my (%args) = @_;
    croak 'Missing "deployer_resource_group" argument' unless $args{deployer_resource_group};

    my $vm_name = script_output("az vm list --resource-group $args{deployer_resource_group} --query [].name --output tsv");
    my $az_query_cmd = join(' ', 'az', 'vm', 'list-ip-addresses', '--resource-group', $args{deployer_resource_group},
        '--name', $vm_name, '--query', '"[].virtualMachine.network.publicIpAddresses[0].ipAddress"', '-o', 'tsv');

    my $ip_addr = script_output($az_query_cmd);
    croak "Not a valid ip addr: $ip_addr" unless grep /^$RE{net}{IPv4}$/, $ip_addr;
    record_info('Deployer data', "Deployer resource group: $args{deployer_resource_group} \nDeployer VM IP: $ip_addr");
    return $ip_addr;
}

=head2 sdaf_prepare_ssh_keys

    sdaf_prepare_ssh_keys(deployer_key_vault=>$deployer_key_vault);

B<deployer_key_vault>: Deployer key vault name

Retrieves public and private ssh key from DEPLOYER keyvault and sets up permissions.

=cut

sub sdaf_prepare_ssh_keys {
    my (%args) = @_;
    croak 'Missing mandatory argument $args{deployer_key_vault}' unless $args{deployer_key_vault};
    my $home = homedir();
    my %ssh_keys;
    my $az_cmd_out = script_output(
        "az keyvault secret list --vault-name $args{deployer_key_vault} --query [].name --output tsv | grep sshkey");

    foreach (split("\n", $az_cmd_out)) {
        $ssh_keys{id_rsa} = $_ if grep(/sshkey$/, $_);
        $ssh_keys{'id_rsa.pub'} = $_ if grep(/sshkey-pub$/, $_);
    }

    foreach ('id_rsa', 'id_rsa.pub') {
        croak "Couldn't retrieve '$_' from keyvault" unless $ssh_keys{$_};
    }

    assert_script_run("mkdir -p $home/.ssh");
    assert_script_run("chmod 700 $home/.ssh");
    for my $key_file (keys %ssh_keys) {
        az_get_ssh_key(
            deployer_key_vault => $args{deployer_key_vault},
            ssh_key_name => $ssh_keys{$key_file},
            ssh_key_filename => $key_file
        );
    }
    assert_script_run("chmod 600 $home/.ssh/id_rsa");
    assert_script_run("chmod 644 $home/.ssh/id_rsa.pub");
}

=head2 az_get_ssh_key

    az_get_ssh_key(deployer_key_vault=$deployer_key_vault, ssh_key_name=$key_name, ssh_key_filename=$ssh_key_filename);

B<deployer_key_vault>: Deployer key vault name

B<ssh_key_name>: SSH key name residing on keyvault

B<ssh_key_filename>: Target filename for SSH key

Retrieves SSH key from DEPLOYER keyvault.

=cut

sub az_get_ssh_key {
    my (%args) = @_;
    my $home = homedir();
    my $cmd = join(' ',
        'az', 'keyvault', 'secret', 'show',
        '--vault-name', $args{deployer_key_vault},
        '--name', $args{ssh_key_name},
        '--query', 'value',
        '--output', 'tsv', '>', "$home/.ssh/$args{ssh_key_filename}");

    my $rc = 1;
    my $retry = 3;
    while ($rc) {
        $rc = script_run($cmd, output => 'Retrieving SSH keys from Deployer keyvault');
        last unless $rc;
        die 'Failed to retrieve ssh key from keyvault' unless $retry;
        $retry--;
        sleep 5;
    }
}

=head2 serial_console_diag_banner

    serial_console_diag_banner($input_text);

B<input_text>: string that will be printed in uppercase surrounded by '#' to make it more visible in output

Prints a simple line in serial console that highlights a point in output to make it more readable.
Can be used for example to mark start and end of a function or a point in test so it is easier to find while debugging.

=cut

sub serial_console_diag_banner {
    my ($input_text) = @_;
    # make all lines equal length and fill
    my $max_length = 80;
    # leave some space for '#' symbol and dividing spaces
    my $max_string_length = $max_length - 16;
    croak 'No input text specified' unless $input_text;
    croak "Input text is longer than" . $max_string_length . "characters. Make it shorter." unless length($input_text) < $max_string_length;

    # max_length - length of the text - 4x2 dividing spaces
    my $symbol_fill = ($max_length - length($input_text) - 8) / 2;
    $input_text = '#' x $symbol_fill . uc(' ' x 4 . $input_text . ' ' x 4) . '#' x $symbol_fill;
    script_run($input_text, quiet => 1, die_on_timeout => 0, timeout => 1);
}

=head2 set_common_sdaf_os_env

    set_os_env(
        subscription_id=>$subscription_id
        [, env_code=>$env_code]
        [, deployer_vnet_code=>$deployer_vnet_code]
        [, workload_vnet_code=>$workload_vnet_code]
        [, region_code=>$region_code]
        [, sap_sid=>$sap_sid]
        [, sdaf_tfstate_storage_account=$sdaf_tfstate_storage_account]
        [, sdaf_key_vault=>$sdaf_key_vault]
    );

B<subscription_id>: Azure subscription ID

B<env_code>: Code for SDAF deployment env. Default: 'SDAF_ENV_CODE'

B<deployer_vnet_code>: Deployer virtual network code. Default 'SDAF_DEPLOYER_VNET_CODE'

B<workload_vnet_code>: Virtual network code for workload zone. Default: 'SDAF_WORKLOAD_VNET_CODE'

B<region_code>: SDAF internal code for azure region. Default: 'SDAF_REGION_CODE'

B<sap_sid>: SAP system ID. Default 'SAP_SID'

B<sdaf_tfstate_storage_account>: Storage account residing in library resource group.
Location for stored tfstate files. Default 'SDAF_TFSTATE_STORAGE_ACCOUNT'

B<sdaf_key_vault>: Key vault name inside Deployer resource group. Default 'SDAF_KEY_VAULT'

Sets up common OS env variables required by SDAF in .bashrc and loads them.
OS env variables are core of how to execute SDAF and many are used even internally by SDAF code.
For detailed variable description check : L<https://learn.microsoft.com/en-us/azure/sap/automation/naming>

=cut

sub set_common_sdaf_os_env {
    my (%args) = @_;
    my $deployment_dir = deployment_dir(create => 'yes');

    $args{env_code} //= get_required_var('SDAF_ENV_CODE');
    $args{deployer_vnet_code} //= get_required_var('SDAF_DEPLOYER_VNET_CODE');
    $args{workload_vnet_code} //= get_required_var('SDAF_WORKLOAD_VNET_CODE');
    $args{region_code} //= get_required_var('SDAF_REGION_CODE');
    $args{sap_sid} //= get_required_var('SAP_SID');
    $args{sdaf_tfstate_storage_account} //= get_required_var('SDAF_TFSTATE_STORAGE_ACCOUNT');
    $args{sdaf_key_vault} //= get_required_var('SDAF_KEY_VAULT');

    my @variables = (
        "export env_code=$args{env_code}",
        "export deployer_vnet_code=$args{deployer_vnet_code}",
        "export workload_vnet_code=$args{workload_vnet_code}",
        "export sap_env_code=$args{env_code}",
        "export deployer_env_code=$args{env_code}",
        "export region_code=$args{region_code}",
        "export SID=$args{sap_sid}",
        "export ARM_SUBSCRIPTION_ID=$args{subscription_id}",
        "export SAP_AUTOMATION_REPO_PATH=$deployment_dir/sap-automation/",
        'export DEPLOYMENT_REPO_PATH=${SAP_AUTOMATION_REPO_PATH}',
        "export CONFIG_REPO_PATH=$deployment_dir/WORKSPACES",
        'export deployer_parameter_file=' . get_tfvars_path(deployment_type => 'deployer', vnet_code => $args{deployer_vnet_code}, %args),
        'export library_parameter_file=' . get_tfvars_path(deployment_type => 'library', %args),
        'export sap_system_parameter_file=' . get_tfvars_path(deployment_type => 'sap_system', vnet_code => $args{workload_vnet_code}, %args),
        'export workload_zone_parameter_file=' . get_tfvars_path(deployment_type => 'workload_zone', vnet_code => $args{workload_vnet_code}, %args),
        "export tfstate_storage_account=$args{sdaf_tfstate_storage_account}",
        "export key_vault=$args{sdaf_key_vault}"
    );

    create_sdaf_os_var_file(\@variables);
}

=head2 get_tfvars_path

    get_tfvars_path(
        deployment_type=>$deployment_type,
        env_code=>$env_code,
        region_code=>$region_code,
        [vnet_code=>$vnet_code,
        sap_sid=>$sap_sid]);

Returns full tfvars filepath respective to deployment type.

B<deployment_type>: Type of the deployment (workload_zone, sap_system, library... etc)

B<env_code>:  SDAF parameter for environment code (for our purpose we can use 'LAB')

B<region_code>: SDAF parameter to choose PC region. Note SDAF is using internal abbreviations (SECE = swedencentral)

B<vnet_code>: SDAF parameter for virtual network code. Library and deployer use different vnet than SUT env

B<sap_sid>: SDAF parameter for sap system ID

=cut

sub get_tfvars_path {
    my (%args) = @_;
    my @supported_types = ('workload_zone', 'sap_system', 'library', 'deployer');
    # common mandatory args

    my @mandatory_args = qw(deployment_type env_code region_code);
    # library does not require 'vnet_code'
    push @mandatory_args, 'vnet_code' unless $args{deployment_type} eq 'library';
    # only sap_system requires 'sap_sid'
    push @mandatory_args, 'sap_sid' if $args{deployment_type} eq 'sap_system';

    foreach (@mandatory_args) { croak "Missing mandatory argument: '$_'" unless defined($args{$_}); }
    croak "Invalid deployment type: $args{deployment_type}\nCurrently supported ones are: " . join(', ', @supported_types)
      unless grep(/^$args{deployment_type}$/, @supported_types);

    # Only workload and sap SUT needs unique ID
    my $job_id = get_current_job_id();

    my $file_path;
    if ($args{deployment_type} eq 'workload_zone') {
        my $env_reg_vnet = join('-', $args{env_code}, $args{region_code}, $args{vnet_code});
        $file_path = "LANDSCAPE/$env_reg_vnet-INFRASTRUCTURE/$env_reg_vnet-INFRASTRUCTURE-$job_id.tfvars";
    }
    elsif ($args{deployment_type} eq 'deployer') {
        my $env_reg_vnet = join('-', $args{env_code}, $args{region_code}, $args{vnet_code});
        $file_path = "DEPLOYER/$env_reg_vnet-INFRASTRUCTURE/$env_reg_vnet-INFRASTRUCTURE.tfvars";
    }
    elsif ($args{deployment_type} eq 'library') {
        my $env_reg = join('-', $args{env_code}, $args{region_code});
        $file_path = "LIBRARY/$env_reg-SAP_LIBRARY/$env_reg-SAP_LIBRARY.tfvars";
    }
    elsif ($args{deployment_type} eq 'sap_system') {
        my $env_reg_vnet_sid = join('-', $args{env_code}, $args{region_code}, $args{vnet_code}, $args{sap_sid});
        $file_path = "SYSTEM/$env_reg_vnet_sid/$env_reg_vnet_sid-$job_id.tfvars";
    }

    my $result = join('/', deployment_dir(), 'WORKSPACES', $file_path);
    return $result;
}

=head2 prepare_sdaf_repo

   prepare_sdaf_repo(
        [, env_code=>$env_code]
        [, region_code=>$region_code]
        [, workload_vnet_code=>$workload_vnet_code]
        [, deployervnet_code=>$workload_vnet_code]
        [, sap_sid=>$sap_sid]);

Prepares directory structure and Clones git repository for SDAF samples and automation code.

B<env_code>: Code for SDAF deployment env. Default: 'SDAF_ENV_CODE'

B<deployer_vnet_code>: Deployer virtual network code. Default 'SDAF_DEPLOYER_VNET_CODE'

B<workload_vnet_code>: Virtual network code for workload zone. Default: 'SDAF_WORKLOAD_VNET_CODE'

B<region_code>: SDAF internal code for azure region. Default: 'SDAF_REGION_CODE'

B<sap_sid>: SAP system ID. Default 'SAP_SID'

=cut

sub prepare_sdaf_repo {
    my (%args) = @_;
    $args{env_code} //= get_required_var('SDAF_ENV_CODE');
    $args{deployer_vnet_code} //= get_required_var('SDAF_DEPLOYER_VNET_CODE');
    $args{workload_vnet_code} //= get_required_var('SDAF_WORKLOAD_VNET_CODE');
    $args{region_code} //= get_required_var('SDAF_REGION_CODE');
    $args{sap_sid} //= get_required_var('SAP_SID');

    my $deployment_dir = deployment_dir(create => 'yes');
    my @git_repos = ("https://github.com/Azure/sap-automation.git sap-automation",
        "https://github.com/Azure/sap-automation-samples.git samples");

    assert_script_run("cd $deployment_dir");
    assert_script_run('mkdir -p ' . log_dir());

    foreach (@git_repos) {
        record_info('Clone repo', "Cloning SDAF repository: $_");
        assert_script_run("git clone $_ --quiet");
    }

    assert_script_run("cp -Rp samples/Terraform/WORKSPACES $deployment_dir/WORKSPACES");
    # Ensure correct directories are in place
    my %vnet_codes = (
        workload_zone => $args{workload_vnet_code},
        sap_system => $args{workload_vnet_code},
        library => '',
        deployer => $args{deployer_vnet_code}
    );

    my @create_workspace_dirs;
    for my $deployment_type ('workload_zone', 'sap_system', 'library', 'deployer') {
        my $tfvars_file = get_tfvars_path(
            vnet_code => $vnet_codes{$deployment_type},
            sap_sid => $args{sap_sid},
            region_code => $args{region_code},
            env_code => $args{env_code},
            deployment_type => $deployment_type
        );

        push(@create_workspace_dirs, dirname($tfvars_file));
    }

    assert_script_run("mkdir -p $_") foreach @create_workspace_dirs;
}

=head2 cleanup_sdaf_files

    cleanup_sdaf_files();

Cleans up all SDAF deployment files belonging to the running test.

=cut

sub cleanup_sdaf_files {
    assert_script_run('rm -Rf ' . deployment_dir);
}
