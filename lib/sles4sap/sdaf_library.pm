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
use utils qw(write_sut_file file_content_replace);

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
Since SUT VMs have no public IPs, this is also serving as a jump-host to reach them via SSH.

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
  generate_resource_group_name
  set_os_variable
  prepare_tfvars_file
  sdaf_deploy_workload_zone
  load_os_env_variables
  sdaf_cleanup
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

=head2 env_variable_file

    env_variable_file();

Returns full path to a file containing all required SDAF OS env variables.
Sourcing this file is essential for running SDAF.

=cut

sub env_variable_file {
    return deployment_dir() . '/sdaf_variables';
}

=head2 log_command_output

    log_command_output(command=>$command, log_file=>$log_file);

B<command>: Command which output should be logged into file.

B<log_file>: Full log file path and filename to pipe command output into.

Using C<'tee'> to redirect command output into log does not return code for executed command, but execution of C<'tee'> itself.
This function transforms given command so the RC reflects exit code of the command itself instead of C<'tee'>.
Function returns only string with transformed command, nothing is being executed.

Command structure: "(command_to_execute 2>$1 | tee /log/file.log; exit ${PIPESTATUS[0]})"

    'exit ${PIPESTATUS[0]}' - returns 'command_to_execute' return code instead of one from 'tee'
    (...) - puts everything into subshell to prevent 'exit' logging out of current shell
    tee - writes output also into the log file


=cut

sub log_command_output {
    my (%args) = @_;
    foreach ('command', 'log_file') {
        croak "Missing mandatory argument: $_" unless $args{$_};
    }

    my $result = join(' ', '(', $args{command}, '2>&1', '|', 'tee', $args{log_file}, ';', 'exit', '${PIPESTATUS[0]})');
    return $result;
}

=head2 az_login

 az_login();

Logs into azure account using SPN credentials. Those are not typed directly into the command but using OS env variables.
To avoid exposure of credentials in serial console, there is a special temporary file used which contains required variables.

SPN credentials are defined by secret OpenQA parameters:

B<_SECRET_AZURE_SDAF_APP_ID>

B<_SECRET_AZURE_SDAF_APP_PASSWORD>

B<_SECRET_AZURE_SDAF_TENANT_ID>

SDAF needs SPN credentials with special permissions. Check link below for details.
L<https://learn.microsoft.com/en-us/azure/sap/automation/deploy-control-plane?tabs=linux#prepare-the-deployment-credentials>

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

    write_sut_file(env_variable_file, join("\n", @$entries));
    assert_script_run('source ' . env_variable_file, quiet => 1);
}

=head2 set_os_variable

    set_os_variable($variable_name, $variable_value);

B<$variable_name>: Variable name

B<$variable_value>: Variable value. Empty value is accepted as well.

Adds or replaces existing OS env variable value in env variable file (see function 'set_common_sdaf_os_env()').
File is sourced afterwards to load the value. Croaks with incorrect usage.

B<WARNING>: This is executed via 'assert_script_run' therefore output will be visible in logs

=cut

sub set_os_variable {
    my ($variable_name, $variable_value) = @_;
    croak 'Missing mandatory argument "$variable_name"' unless $variable_name;

    my $env_variable_file = env_variable_file();

    if (!script_run("grep 'export $variable_name=' $env_variable_file")) {
        file_content_replace($env_variable_file, "export $variable_name=.*" => "export $variable_name=\"$variable_value\"");
    }
    else {
        assert_script_run("echo 'export $variable_name=\"$variable_value\"' >> $env_variable_file");
    }

    # Activate new variable
    load_os_env_variables();
    record_info('ENV set', "Env variable '$variable_name' is set to '$variable_value' ");
}

=head2 get_os_variable

    get_os_variable($variable_name);

B<$variable_name>: Variable name

Returns value of requested OS env variable name.
Variable is acquired using C<'echo'> command and is visible in serial terminal output.
Keep in mind, this variable is only active until logout.

=cut

sub get_os_variable {
    my ($variable_name) = @_;
    croak 'Positional argument $variable_name not defined' unless $variable_name;
    $variable_name =~ s/[\$}{]//g;

    return script_output("echo \${$variable_name}", quiet => 1);
}

=head2 set_common_sdaf_os_env

    set_common_sdaf_os_env(
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

B<deployer_vnet_code>: Deployer virtual network code. Default: 'SDAF_DEPLOYER_VNET_CODE'

B<workload_vnet_code>: Virtual network code for workload zone. Default: 'SDAF_WORKLOAD_VNET_CODE'

B<region_code>: SDAF internal code for azure region. Default: 'SDAF_REGION_CODE'

B<sap_sid>: SAP system ID. Default: 'SAP_SID'

B<sdaf_tfstate_storage_account>: Storage account residing in library resource group.
Location for stored tfstate files. Default 'SDAF_TFSTATE_STORAGE_ACCOUNT'

B<sdaf_key_vault>: Key vault name inside Deployer resource group. Default 'SDAF_KEY_VAULT'

Creates a file with common OS env variables required to run SDAF. File is sourced afterwards to make the values active.
Keep in mind that values are lost after user logout (for example after disconnecting console redirection).
You can load them back using I<load_os_env_variables()> function
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
        # Deployer state is a file existing in LIBRARY storage account, default value is SDAF default.
'export deployerState=' . get_var('SDAF_DEPLOYER_TFSTATE', '${deployer_env_code}-${region_code}-${deployer_vnet_code}-INFRASTRUCTURE.terraform.tfstate'),
        "export key_vault=$args{sdaf_key_vault}",
        "\n"    # Newline is required otherwise "echo 'something' >> file" will just append content to the last line
    );

    create_sdaf_os_var_file(\@variables);
}

=head2 load_os_env_variables

    load_os_env_variables();

Sources file containing OS env variables required for executing SDAF.
Currently deployer VM is a permanent installation with all tests using it. Therefore using .bashrc file for storing
variables is not an option since tests would constantly overwrite variables between each other.

=cut

sub load_os_env_variables {
    assert_script_run('source ' . env_variable_file);
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

=head2 prepare_tfvars_file

    prepare_tfvars_file(deployment_type=>$deployment_type);

B<$deployment_type>: Type of the deployment (workload_zone, sap_system, library... etc)

Downloads tfvars template files from openQA data dir and places them into correct place within SDAF repo structure.
Returns full path of the tfvars file.

=cut

sub prepare_tfvars_file {
    my (%args) = @_;
    my %tfvars_os_variable = (
        deployer => 'deployer_parameter_file',
        sap_system => 'sap_system_parameter_file',
        workload_zone => 'workload_zone_parameter_file',
        library => 'library_parameter_file'
    );
    my %tfvars_template_url = (
        deployer => data_url('sles4sap/sdaf/DEPLOYER.tfvars'),
        sap_system => data_url('sles4sap/sdaf/SAP_SYSTEM.tfvars'),
        workload_zone => data_url('sles4sap/sdaf/WORKLOAD_ZONE.tfvars'),
        library => data_url('sles4sap/sdaf/LIBRARY.tfvars')
    );
    croak 'Deployment type not specified' unless $args{deployment_type};
    croak "Unknown deployment type: $args{deployment_type}" unless $tfvars_os_variable{$args{deployment_type}};

    my $tfvars_file = get_os_variable($tfvars_os_variable{$args{deployment_type}});
    my $retrieve_tfvars_cmd = join(' ', 'curl', '-v', '-fL', $tfvars_template_url{$args{deployment_type}}, '-o', $tfvars_file);

    assert_script_run($retrieve_tfvars_cmd);
    assert_script_run("test -f $tfvars_file");
    replace_tfvars_variables($tfvars_file);
    upload_logs($tfvars_file, log_name => "$args{deployment_type}.tfvars");
    return $tfvars_file;
}

=head2 replace_tfvars_variables

    replace_tfvars_variables();

B<$deployment_type>: Type of the deployment (workload_zone, sap_system, library... etc)

Replaces placeholder pattern B<%OPENQA_VARIABLE%> with corresponding OpenQA variable value.
If OpenQA variable is not set, placeholder is replaced with empty value.

=cut

sub replace_tfvars_variables {
    my ($tfvars_file) = @_;
    croak 'Variable "$tfvars_file" undefined' unless defined($tfvars_file);
    my @variables = qw(SDAF_ENV_CODE SDAF_LOCATION SDAF_RESOURCE_GROUP SDAF_VNET_CODE SAP_SID);
    my %to_replace = map { '%' . $_ . '%' => get_var($_, '') } @variables;
    file_content_replace($tfvars_file, %to_replace);
}

=head2 sdaf_deploy_workload_zone

    sdaf_deploy_workload_zone();

Executes SDAF workload zone deployment. SDAF relies on OS env variables therefore those are passed as cmd args as well.
Definitely keep I<--spn-secret> set as a reference to OS variable I<${ARM_CLIENT_SECRET}>, otherwise password will
be shown in openQA output log in plaintext.
L<https://learn.microsoft.com/en-us/azure/sap/automation/deploy-workload-zone?tabs=linux#deploy-the-sap-workload-zone>

=cut

sub sdaf_deploy_workload_zone {
    my ($tfvars_filename, $tfvars_path) = fileparse(get_os_variable('workload_zone_parameter_file'));
    # Variable is specific to each deployment type and will be changed during the course of whole deployment process.
    # It is used by SDAF internally, so keep it set in OS env
    set_os_variable('parameterFile', $tfvars_filename);

    # SDAF has to be executed from the profile directory
    assert_script_run("cd $tfvars_path");
    my $deploy_command = join(' ', deployment_dir() . '/sap-automation/deploy/scripts/install_workloadzone.sh',
        '--parameterfile', $tfvars_filename,    # workload zone tfvars file
        '--deployer_environment', '${deployer_env_code}',    # VNET code
        '--deployer_tfstate_key', '${deployerState}',    # tfstate name. State file is stored in storage account.
        '--keyvault', '${key_vault}',    # Deployer key vault containing credentials
        '--storageaccountname', '${tfstate_storage_account}',    # storage account for tfstate
        '--subscription', '${ARM_SUBSCRIPTION_ID}',
        '--tenant_id', '${ARM_TENANT_ID}',
        '--spn_id', '${ARM_CLIENT_ID}',
        '--spn_secret', '${ARM_CLIENT_SECRET}',
        '--auto-approve');    # avoid user interaction

    record_info('SDAF exe', "Executing workload zone deployment: $deploy_command");

    my $output_log_file = log_dir() . "/deploy_workload_zone.log";
    $deploy_command = log_command_output(command => $deploy_command, log_file => $output_log_file);
    my $rc = script_run($deploy_command, timeout => 1800);

    upload_logs($output_log_file, log_name => 'deploy_workload_zone.log');    # upload logs before failing
    die "Workload zone deployment failed with RC: $rc" if $rc;
    record_info('Deploy done');
}

=head2 prepare_sdaf_repo

   prepare_sdaf_repo(
        [, env_code=>$env_code]
        [, region_code=>$region_code]
        [, workload_vnet_code=>$workload_vnet_code]
        [, deployer_vnet_code=>$workload_vnet_code]
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
        library => '',    # SDAF Library is not part of any VNET
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

=head2 generate_resource_group_name

    generate_resource_group_name(deployment_type=>$deployment_type);

B<$deployment_type>: Type of the deployment (workload_zone, sap_system, library... etc)

Returns name of the resource group for the deployment type specified by B<$deployment_type> .
Resource group pattern: I<SDAF-OpenQA-[deployment type]-[deployment id]-[OpenQA job id]>

=cut

sub generate_resource_group_name {
    my (%args) = @_;
    my @supported_types = ('workload_zone', 'sap_system', 'library', 'deployer');
    croak "Unsupported deployment type: $args{deployment_type}\nCurrently supported ones are: @supported_types" unless
      grep(/^$args{deployment_type}$/, @supported_types);
    my $job_id = get_current_job_id();

    return join('-', 'SDAF', 'OpenQA', $args{deployment_type}, $job_id);
}

=head2 resource_group_exists

    resource_group_exists($resource_group);

B<$resource_group>: Resource group name to check

Checks if resource group exists. Function accepts only full resource name.
Croaks if command does not return true/false value.

=cut

sub resource_group_exists {
    my ($resource_group) = @_;
    croak 'Mandatory positional argument "$resource_group" not defined.' unless $resource_group;

    my $cmd_out = script_output("az group exists -n $resource_group");
    die "Command 'az group exists -n $resource_group' failed.\nCommand returned: $cmd_out" unless grep /false|true/, $cmd_out;
    return ($cmd_out eq 'true');
}

=head2 sdaf_execute_remover

    sdaf_execute_remover(deployment_type=>$deployment_type);

B<$deployment_type>: Type of the deployment (workload_zone, sap_system)

Uses remover.sh script which is part of the SDAF project. This script can be used only on workload zone or sap system.
Control plane and library have separate removal script, but are currently part of permanent setup and should not be destroyed.
Returns RC to allow additional cleanup tasks required even after script failure.
L<https://learn.microsoft.com/en-us/azure/sap/automation/bash/remover>

=cut

sub sdaf_execute_remover {
    my (%args) = @_;
    croak 'Missing mandatory positional argument "$deployment_type"' unless $args{deployment_type};
    croak 'This function can be used only on sap system and workload zone removal' unless
      grep /^$args{deployment_type}$/, ('sap_system', 'workload_zone');

    # SDAF remover.sh uses term 'sap_landscape' for 'workload_zone'.
    my $type_parameter = $args{deployment_type} eq 'workload_zone' ? 'sap_landscape' : $args{deployment_type};

    my $tfvars_file;
    $tfvars_file = get_os_variable('sap_system_parameter_file') if $args{deployment_type} eq 'sap_system';
    $tfvars_file = get_os_variable('workload_zone_parameter_file') if $args{deployment_type} eq 'workload_zone';
    die 'Function failed to retrieve tfvars file via OS variable.' unless $tfvars_file;

    my ($tfvars_filename, $tfvars_path) = fileparse($tfvars_file);
    my $remover_cmd = join(' ',
        deployment_dir() . '/sap-automation/deploy/scripts/remover.sh',
        '--parameterfile', $tfvars_filename,
        '--type', $type_parameter,
        '--auto-approve');

    # capture command output into log file
    my $output_log_file = log_dir() . "/cleanup_$args{deployment_type}.log";
    $remover_cmd = log_command_output(command => $remover_cmd, log_file => $output_log_file);

    # SDAF must be executed from the profile directory, otherwise it will fail
    assert_script_run("cd " . $tfvars_path);
    record_info('SDAF destroy', "Executing SDAF remover:\n$remover_cmd");
    my $rc = script_run($remover_cmd, timeout => 3600);
    upload_logs($output_log_file, log_name => $output_log_file);

    # Do not kill the test, only return RC. There are still files to be cleaned up on deployer VM side.
    return $rc;
}

=head2 sdaf_cleanup

    sdaf_cleanup();

Performs full cleanup routine for B<sap systems> and B<workload zone> by executing SDAF remover.sh file.
Deletes all files related to test run on deployer VM, even in case remover script fails.
Resource groups need to be deleted manually in case of failure.

=cut

sub sdaf_cleanup {
    my $remover_rc = 1;
    # Sap system needs to be destroyed before workload zone so order matters here.
    for my $deployment_type ('sap_system', 'workload_zone') {
        my $resource_group = resource_group_exists(generate_resource_group_name(deployment_type => $deployment_type));
        unless ($resource_group) {
            record_info('Cleanup skip', "Resource group for deployment type '$deployment_type' does not exist. Skipping cleanup");
            next;
        }

        $remover_rc = sdaf_execute_remover(deployment_type => $deployment_type);
        if ($remover_rc) {
            # Cleanup files from deployer VM before killing test
            assert_script_run('rm -Rf ' . deployment_dir);
            die('SDAF remover script failed. Please check logs and delete resource groups manually');
        }
    }
    assert_script_run('rm -Rf ' . deployment_dir);
    record_info('Cleanup files', join(' ', 'Deployment directory', deployment_dir(), 'was deleted.'));
}
