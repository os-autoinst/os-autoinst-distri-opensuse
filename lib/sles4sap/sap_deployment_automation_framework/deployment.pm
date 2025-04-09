# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
#
# Library used for Microsoft SDAF deployment

package sles4sap::sap_deployment_automation_framework::deployment;

use strict;
use warnings;
use version;
use testapi;
use Exporter qw(import);
use Carp qw(croak);
use Utils::Git qw(git_clone);
use File::Basename;
use Regexp::Common qw(net);
use utils qw(write_sut_file file_content_replace);
use Scalar::Util 'looks_like_number';
use Mojo::JSON qw(decode_json);
use sles4sap::azure_cli qw(az_keyvault_secret_list az_keyvault_secret_show);
use sles4sap::sap_deployment_automation_framework::naming_conventions qw(
  homedir
  deployment_dir
  log_dir
  sdaf_scripts_dir
  env_variable_file
  get_tfvars_path
  generate_resource_group_name
  convert_region_to_short
  get_workload_vnet_code
);

our @EXPORT = qw(
  $output_log_file
  az_login
  sdaf_ssh_key_from_keyvault
  serial_console_diag_banner
  set_common_sdaf_os_env
  prepare_sdaf_project
  set_os_variable
  get_os_variable
  sdaf_execute_deployment
  load_os_env_variables
  sdaf_cleanup
  sdaf_execute_playbook
  ansible_execute_command
  ansible_show_status
  playbook_settings
  sdaf_register_byos
  get_sdaf_instance_id
  sdaf_deployment_reused
);

our $output_log_file = '';

=head1 SYNOPSIS

Library with common functions for Microsoft SDAF deployment automation. Documentation can be found on the
L<projects official website|https://learn.microsoft.com/en-us/azure/sap/automation/get-started>

Github repositories:
L<Automation scripts|https://github.com/Azure/sap-automation/tree/main>
L<Sample configurations|https://github.com/Azure/SAP-automation-samples/tree/main>

Basic terminology:

=over

=item * B<SDAF>: SAP deployment automation framework

=item * B<Control plane>: Common term for Resource groups B<Deployer> and B<Library>.
Generally it is part of a permanent infrastructure in the cloud.

=item * B<Deployer>: Resource group providing services such as keyvault, Deployer VM and associated resources.

=item * B<Deployer VM>: Central point that contains SDAF installation and where the deployment is executed from.
Since SUT VMs have no public IPs, this is also serving as a jump-host to reach them via SSH.

=item * B<Library>: Resource group providing storage for terraform state files, SAP media and private DNS zone.

=item * B<Workload zone>: Resource group that provides services similar to support server.

=item * B<SAP Systems>: Resource group containing SAP SUTs and related resources.

=back
=cut

=head2 log_command_output

    log_command_output(command=>$command, log_file=>$log_file);

Using C<'tee'> to redirect command output into log does not return code for executed command, but execution of C<'tee'> itself.
This function transforms given command so the RC reflects exit code of the command itself instead of C<'tee'>.
Function returns only string with transformed command, nothing is being executed.

Command structure: "(command_to_execute 2>$1 | tee /log/file.log; exit ${PIPESTATUS[0]})"

    'exit ${PIPESTATUS[0]}' - returns 'command_to_execute' return code instead of one from 'tee'
    (...) - puts everything into subshell to prevent 'exit' logging out of current shell
    tee - writes output also into the log file

=over

=item * B<command>: Command which output should be logged into file.

=item * B<log_file>: Full log file path and filename to pipe command output into.

=back
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

=over

=item * B<_SECRET_AZURE_SDAF_APP_ID>

=item * B<_SECRET_AZURE_SDAF_APP_PASSWORD>

=item * B<_SECRET_AZURE_SDAF_TENANT_ID>

=back

SDAF needs SPN credentials with special permissions. Check link below for details.
L<https://learn.microsoft.com/en-us/azure/sap/automation/deploy-control-plane?tabs=linux#prepare-the-deployment-credentials>

=cut

sub az_login {
    my $temp_file = '/tmp/az_login_tmp';
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
    assert_script_run($login_cmd, timeout => 30);

    my $subscription_id = script_output('az account show -o tsv --query id');
    record_info('AZ login', "Subscription id: $subscription_id");

    # Remove temp file with credentials.
    assert_script_run("rm $temp_file");
    return ($subscription_id);
}

=head2 create_sdaf_os_var_file

    create_sdaf_os_var_file($entries);

Creates a simple file with bash env variables and uploads it to the target host without revealing content in serial console.
File is sourced afterwards.
For detailed variable description check : L<https://learn.microsoft.com/en-us/azure/sap/automation/naming>

=over

=item * B<$entries>: ARRAYREF of entries to be appended to variable source file

=back
=cut

sub create_sdaf_os_var_file {
    my ($entries) = @_;
    croak 'Expected an ARRAYREF but got: ' . ref $entries if (ref $entries ne 'ARRAY');

    write_sut_file(env_variable_file, join("\n", @$entries));
    assert_script_run('source ' . env_variable_file, quiet => 1);
}

=head2 set_os_variable

    set_os_variable($variable_name, $variable_value);

Adds or replaces existing OS env variable value in env variable file (see function 'set_common_sdaf_os_env()').
File is sourced afterwards to load the value. Croaks with incorrect usage.

B<WARNING>: This is executed via 'assert_script_run' therefore output will be visible in logs

=over

=item * B<$variable_name>: Variable name

=item * B<$variable_value>: Variable value. Empty value is accepted as well.

=back
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

Returns value of requested OS env variable name.
Variable is acquired using C<'echo'> command and is visible in serial terminal output.
Keep in mind, this variable is only active until logout.

=over

=item * B<$variable_name>: Variable name

=back
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
        [, sdaf_region_code=>$sdaf_region_code]
        [, sap_sid=>$sap_sid]
        [, sdaf_tfstate_storage_account=$sdaf_tfstate_storage_account]
        [, sdaf_key_vault=>$sdaf_key_vault]
    );

Creates a file with common OS env variables required to run SDAF. File is sourced afterwards to make the values active.
Keep in mind that values are lost after user logout (for example after disconnecting console redirection).
You can load them back using I<load_os_env_variables()> function
OS env variables are core of how to execute SDAF and many are used even internally by SDAF code.
For detailed variable description check : L<https://learn.microsoft.com/en-us/azure/sap/automation/naming>

=over

=item * B<subscription_id>: Azure subscription ID

=item * B<env_code>: Code for SDAF deployment env. Default: 'SDAF_ENV_CODE'

=item * B<deployer_vnet_code>: Deployer virtual network code. Default: 'SDAF_DEPLOYER_VNET_CODE'

=item * B<sdaf_region_code>: SDAF internal code for azure region. Default: 'PUBLIC_CLOUD_REGION' - converted to SDAF format

=item * B<sap_sid>: SAP system ID. Default: 'SAP_SID'

=item * B<sdaf_tfstate_storage_account>: Storage account residing in library resource group.
Location for stored tfstate files. Default 'SDAF_TFSTATE_STORAGE_ACCOUNT'

=item * B<sdaf_key_vault>: Key vault name inside Deployer resource group. Default 'SDAF_DEPLYOER_KEY_VAULT'

=back
=cut

sub set_common_sdaf_os_env {
    my (%args) = @_;
    my $deployment_dir = deployment_dir(create => 'yes');

    $args{env_code} //= get_required_var('SDAF_ENV_CODE');
    $args{deployer_vnet_code} //= get_required_var('SDAF_DEPLOYER_VNET_CODE');
    $args{sdaf_region_code} //= convert_region_to_short(get_required_var('PUBLIC_CLOUD_REGION'));
    $args{sap_sid} //= get_required_var('SAP_SID');
    $args{sdaf_tfstate_storage_account} //= get_required_var('SDAF_TFSTATE_STORAGE_ACCOUNT');
    $args{sdaf_key_vault} //= get_required_var('SDAF_DEPLYOER_KEY_VAULT');
    my $workload_vnet_code = get_workload_vnet_code();

    # This is used later filling up tfvars files.
    set_var('SDAF_REGION_CODE', $args{sdaf_region_code});

    my @variables = (
        "export env_code=$args{env_code}",
        "export deployer_vnet_code=$args{deployer_vnet_code}",
        "export workload_vnet_code=$workload_vnet_code",
        "export sap_env_code=$args{env_code}",
        "export deployer_env_code=$args{env_code}",
        "export sdaf_region_code=$args{sdaf_region_code}",
        "export SID=$args{sap_sid}",
        "export ARM_SUBSCRIPTION_ID=$args{subscription_id}",
        "export SAP_AUTOMATION_REPO_PATH=$deployment_dir/sap-automation/",
        'export DEPLOYMENT_REPO_PATH=${SAP_AUTOMATION_REPO_PATH}',
        "export CONFIG_REPO_PATH=$deployment_dir/WORKSPACES",
        'export deployer_parameter_file=' . get_tfvars_path(deployment_type => 'deployer', vnet_code => $args{deployer_vnet_code}, %args),
        'export library_parameter_file=' . get_tfvars_path(deployment_type => 'library', %args),
        'export sap_system_parameter_file=' . get_tfvars_path(deployment_type => 'sap_system', vnet_code => $workload_vnet_code, %args),
        'export workload_zone_parameter_file=' . get_tfvars_path(deployment_type => 'workload_zone', vnet_code => $workload_vnet_code, %args),
        "export tfstate_storage_account=$args{sdaf_tfstate_storage_account}",
        # Deployer state is a file existing in LIBRARY storage account, default value is SDAF default.
'export deployerState=' . get_var('SDAF_DEPLOYER_TFSTATE', '${deployer_env_code}-${sdaf_region_code}-${deployer_vnet_code}-INFRASTRUCTURE.terraform.tfstate'),
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
    assert_script_run('source ' . env_variable_file());
}

=head2 sdaf_ssh_key_from_keyvault

    sdaf_ssh_key_from_keyvault(key_vault=>$key_vault [, target_file=>'/path/to/glory/and_happiness']);

Retrieves public and private ssh key from specified keyvault and sets up permissions.

=over

=item * B<key_vault>: Key vault name

=item * B<target_file>: Full file path, where to write the public key. Default '~/.ssh/id_rsa'

=back
=cut

sub sdaf_ssh_key_from_keyvault {
    my (%args) = @_;
    croak 'Missing mandatory argument: key_vault' unless $args{key_vault};
    $args{target_file} //= homedir() . '/.ssh/id_rsa';
    my ($target_filename, $target_path) = fileparse($args{target_file});
    my @secret_ids = @{az_keyvault_secret_list(
            vault_name => $args{key_vault}, query => '"[?ends_with(name, \'sshkey\')].id"')};

    croak "Multiple or no secrets found: \n" . join("\n", @secret_ids) unless @secret_ids == 1;

    # Ensure private key file exists and has correct permissions
    assert_script_run("mkdir -p $target_path");
    assert_script_run("chmod 700 $target_path");
    assert_script_run("touch $args{target_file}");
    assert_script_run("chmod 600 $target_path/$target_filename");

    my $private_key_content;

    # Retry 3 (magic number) times in case of issues with az API
    foreach (1 .. 3) {
        $private_key_content = az_keyvault_secret_show(
            id => $secret_ids[0],
            query => 'value',
            output => 'tsv',
            save_to_file => $args{target_file});

        # Check with ssh-keygen if SSH public key is malformed
        last if !script_run("ssh-keygen -l -f $args{target_file}");
        croak "Failed to retrieve private key content. Content returned: $private_key_content" if $_ == 3;
        # Sleep between retries to give AZ API a little break
        sleep 5;
    }

    record_info('SSH KEY', "SSH public key '$target_path/$target_filename' is ready to be used.");
}

=head2 serial_console_diag_banner

    serial_console_diag_banner($input_text);

Prints a banner in serial console that highlights a point in output to make it more readable.
Can be used for example to mark start and end of a function or a point in test so it is easier to find while debugging.
Below is an example of the printed banner:
# # $input_text #

=over

=item * B<input_text>: string that will be printed in uppercase surrounded by '#' to make it more visible in output

=back
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
    $input_text = '#' x $symbol_fill . ' ' x 4 . $input_text . ' ' x 4 . '#' x $symbol_fill;

    enter_cmd($input_text);
    wait_serial(qr/:~|#|>/, timeout => 5, quiet => 1);
}

=head2 sdaf_execute_deployment

    sdaf_execute_deployment(deployment_type=>$deployment_type [, timeout=>$timeout]);

Executes SDAF deployment according to the type specified.
Croaks with unsupported deployment type, dies upon command failure.
L<https://learn.microsoft.com/en-us/azure/sap/automation/deploy-workload-zone?tabs=linux#deploy-the-sap-workload-zone>
L<https://learn.microsoft.com/en-us/azure/sap/automation/tutorial#deploy-the-sap-system-infrastructure>

=over

=item * B<deployment_type>: Type of the deployment: workload_zone or sap_system

=item * B<timeout>: Execution timeout. Default: 1800s.

=item * B<retries>: Number of attempts to execute deployment in case of failure. Default: 3

=back
=cut

sub sdaf_execute_deployment {
    my (%args) = @_;
    croak 'This function can be used only on sap system and workload zone deployment' unless
      grep /^$args{deployment_type}$/, ('sap_system', 'workload_zone');
    $args{retries} //= 3;
    $args{timeout} //= 1800;
    my $parameter_name = $args{deployment_type} eq 'workload_zone' ? 'workload_zone_parameter_file' : 'sap_system_parameter_file';
    my ($tfvars_filename, $tfvars_path) = fileparse(get_os_variable($parameter_name));

    # Variable is specific to each deployment type and will be changed during the course of whole deployment process.
    # It is used by SDAF internally, so keep it set in OS env
    set_os_variable('parameterFile', $tfvars_filename);

    # SDAF has to be executed from the profile directory
    assert_script_run("cd $tfvars_path");
    my $deploy_command = get_sdaf_deployment_command(
        deployment_type => $args{deployment_type}, tfvars_filename => $tfvars_filename);

    record_info('SDAF exe', "Executing '$args{deployment_type}' deployment: $deploy_command");
    my $rc;
    $output_log_file = log_dir() . "/deploy_$args{deployment_type}_attempt.txt";
    my $attempt_no = 1;
    while ($attempt_no <= $args{retries}) {
        $output_log_file =~ s/attempt/attempt-$attempt_no/;
        $deploy_command = log_command_output(command => $deploy_command, log_file => $output_log_file);
        $rc = script_run($deploy_command, timeout => $args{timeout});
        upload_logs($output_log_file, log_name => $output_log_file);    # upload logs before failing
        last unless $rc;
        record_info("SDAF retry $attempt_no", "Deployment of '$args{deployment_type}' exited with RC '$rc', retrying ...");
        $attempt_no++;
    }

    die "SDAF deployment execution failed with RC: $rc" if $rc;
    record_info('Deploy done');
}


=head2 get_sdaf_deployment_command

    get_sdaf_deployment_command(deployment_type=>$deployment_type, tfvars_filename=>tfvars_filename);

Function composes SDAF deployment script command for B<sap_system> or B<workload_zone> according to official documentation.
Although the documentation uses env OS variable references in the command, function replaces them with actual values.
This is done for better debugging and logging transparency. Only sensitive values are hidden by using references.

=over

=item * B<deployment_type>: Type of the deployment: workload_zone or sap_system

=item * B<tfvars_filename>: Filename of tfvars file

=back
=cut

sub get_sdaf_deployment_command {
    my (%args) = @_;
    my $cmd;
    if ($args{deployment_type} eq 'workload_zone') {
        $cmd = join(' ', sdaf_scripts_dir() . '/install_workloadzone.sh',
            '--parameterfile', $args{tfvars_filename},    # workload zone tfvars file
            '--deployer_environment', get_os_variable('deployer_env_code'),    # VNET code
            '--deployer_tfstate_key', get_os_variable('deployerState'),    # tfstate name. State file is stored in storage account.
            '--keyvault', get_os_variable('key_vault'),    # Deployer key vault containing credentials
            '--storageaccountname', get_os_variable('tfstate_storage_account'),    # storage account for tfstate
            '--subscription', get_os_variable('ARM_SUBSCRIPTION_ID'),
            '--tenant_id', get_os_variable('ARM_TENANT_ID'),
            '--spn_id', '${ARM_CLIENT_ID}',    # Keep secrets hidden in serial output
            '--spn_secret', '${ARM_CLIENT_SECRET}',    #keep secrets hidden in serial output
            '--auto-approve');    # avoid user interaction
    }
    elsif ($args{deployment_type} eq 'sap_system') {
        $cmd = join(' ', sdaf_scripts_dir() . '/installer.sh',
            '--parameterfile', $args{tfvars_filename},
            '--type', 'sap_system',
            '--storageaccountname', get_os_variable('tfstate_storage_account'),
            '--state_subscription', get_os_variable('ARM_SUBSCRIPTION_ID'),
            '--auto-approve');
    }
    else {
        croak("Incorrect deployment type: '$args{deployment_type}'\nOnly 'workload_zone' and 'sap_system' is supported.");
    }
    return $cmd;
}

=head2 prepare_sdaf_project

   prepare_sdaf_project(
        [, env_code=>$env_code]
        [, sdaf_region_code=>$sdaf_region_code]
        [, deployer_vnet_code=>$deployer_vnet_code]
        [, sap_sid=>$sap_sid]);

Prepares directory structure and Clones git repository for SDAF samples and automation code.

=over

=item * B<env_code>: Code for SDAF deployment env. Default: 'SDAF_ENV_CODE'

=item * B<deployer_vnet_code>: Deployer virtual network code. Default 'SDAF_DEPLOYER_VNET_CODE'

=item * B<sdaf_region_code>: SDAF internal code for azure region. Default: 'PUBLIC_CLOUD_REGION' converted to SDAF format

=item * B<sap_sid>: SAP system ID. Default 'SAP_SID'

=back
=cut

sub prepare_sdaf_project {
    my (%args) = @_;
    $args{env_code} //= get_required_var('SDAF_ENV_CODE');
    $args{deployer_vnet_code} //= get_required_var('SDAF_DEPLOYER_VNET_CODE');
    $args{sdaf_region_code} //= convert_region_to_short(get_required_var('PUBLIC_CLOUD_REGION'));
    $args{sap_sid} //= get_required_var('SAP_SID');
    my $workload_vnet_code = get_workload_vnet_code();

    my $deployment_dir = deployment_dir(create => 'yes');

    assert_script_run("cd $deployment_dir");
    assert_script_run('mkdir -p ' . log_dir());

    # Calculate SDAF version used for deployment and picks latest -1
    # SDAF_GIT_AUTOMATION_BRANCH variable will override calculated value
    my $branch = get_var('SDAF_GIT_AUTOMATION_BRANCH', '');
    if (!$branch || $branch eq 'latest') {
        my $tags = script_output("curl -s https://api.github.com/repos/Azure/sap-automation/tags | jq -r '.[].name' | sort -rV");
        record_info("Releases: $tags");
        my @releases = split('\n', $tags);
        my $branch_expected = ($branch eq 'latest') ? $releases[0] : $releases[1];
        # Versions older or equal than 'v3.11.0.3' missing features so report failure
        my $branch_er = version->new('v3.11.0.3');
        $branch_expected = version->new("$branch_expected");
        if ($branch_expected <= $branch_er) {
            die "Version $branch_expected older or equal than $branch_er missing features";
        }
        $branch = $branch_expected;
    }
    record_info("Release: $branch");

    git_clone(get_required_var('SDAF_GIT_AUTOMATION_REPO'),
        branch => $branch,
        depth => '1',
        single_branch => 'yes',
        output_log_file => log_dir() . '/git_clone_automation.txt');

    git_clone(get_required_var('SDAF_GIT_TEMPLATES_REPO'),
        branch => get_var('SDAF_GIT_TEMPLATES_BRANCH'),
        depth => '1',
        single_branch => 'yes',
        output_log_file => log_dir() . '/git_clone_templates.log');

    assert_script_run("cp -Rp sap-automation-samples/Terraform/WORKSPACES $deployment_dir/WORKSPACES");
    # Ensure correct directories are in place
    my %vnet_codes = (
        workload_zone => $workload_vnet_code,
        sap_system => $workload_vnet_code,
        library => '',    # SDAF Library is not part of any VNET
        deployer => $args{deployer_vnet_code}
    );

    my @create_workspace_dirs;
    for my $deployment_type ('workload_zone', 'sap_system', 'library', 'deployer') {
        my $tfvars_file = get_tfvars_path(
            vnet_code => $vnet_codes{$deployment_type},
            sap_sid => $args{sap_sid},
            sdaf_region_code => $args{sdaf_region_code},
            env_code => $args{env_code},
            deployment_type => $deployment_type
        );

        push(@create_workspace_dirs, dirname($tfvars_file));
    }

    assert_script_run("mkdir -p $_") foreach @create_workspace_dirs;
}

=head2 resource_group_exists

    resource_group_exists($resource_group);

Checks if resource group exists. Function accepts only full resource name.
Croaks if command does not return true/false value.

=over

=item * B<$resource_group>: Resource group name to check

=back
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

Uses remover.sh script which is part of the SDAF project. This script can be used only on workload zone or sap system.
Control plane and library have separate removal script, but are currently part of permanent setup and should not be destroyed.
Returns RC to allow additional cleanup tasks required even after script failure.
L<https://learn.microsoft.com/en-us/azure/sap/automation/bash/remover>

=over

=item * B<$deployment_type>: Type of the deployment (workload_zone, sap_system)

=back
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
        sdaf_scripts_dir() . '/remover.sh',
        '--parameterfile', $tfvars_filename,
        '--type', $type_parameter,
        '--auto-approve');

    my $rc;
    $output_log_file = log_dir() . "/cleanup_$args{deployment_type}_attempt.txt";
    my $attempt_no = 1;
    # SDAF must be executed from the profile directory, otherwise it will fail
    assert_script_run("cd " . $tfvars_path);
    while ($attempt_no <= 3) {
        record_info("Attempt #$attempt_no");
        # Capture command output into log file
        $output_log_file =~ s/attempt/attempt-$attempt_no/;
        $remover_cmd = log_command_output(command => $remover_cmd, log_file => $output_log_file);

        record_info('SDAF destroy', "Executing SDAF remover:\n$remover_cmd");
        # Keep the timeout high, definitely above 1H. Azure tends to be slow.
        $rc = script_run($remover_cmd, timeout => 7200);
        upload_logs($output_log_file, log_name => $output_log_file);

        last unless $rc;
        sleep 30;
        record_info("SDAF destroy retry $attempt_no", "destroy of '$args{deployment_type}' exited with RC '$rc', retrying ...");
        $attempt_no++;
    }

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
    assert_script_run('cd');    # navigate out the directory you are about to delete
    assert_script_run('rm -Rf ' . deployment_dir());
    record_info('Cleanup files', join(' ', 'Deployment directory', deployment_dir, 'was deleted.'));
    record_info('SDAF remover', 'SDAF remover scripts finished');
}

=head2 sdaf_execute_playbook

    sdaf_execute_playbook(
        playbook_filename=>'playbook_04_00_01_db_ha.yaml',
        sdaf_config_root_dir=>'/path/to/joy/and/happiness/'
        sap_sid=>'ABC',
        timeout=>'42',
        verbosity_level=>'3'
        );

Execute playbook specified by B<playbook_filename> and record command output in separate log file.
Verbosity level of B<ansible-playbook> is controlled by openQA parameter B<SDAF_ANSIBLE_VERBOSITY_LEVEL>.
If undefined, it will use standard output without adding any B<-v> flag. See function B<sdaf_execute_playbook> for details.

=over

=item * B<playbook_filename>: Filename of the playbook to be executed.

=item * B<sdaf_config_root_dir>: SDAF Config directory containing SUT ssh keys

=item * B<sap_sid>: SAP system ID. Default 'SAP_SID'

=item * B<timeout>: Timeout for executing playbook. Passed into asset_script_run. Default: 1800s

=item * B<$verbosity_level>: Change default verbosity value by either anything equal to 'true' or int between 1-6. Default: false

=back
=cut

sub sdaf_execute_playbook {
    my (%args) = @_;
    $args{timeout} //= 1800;    # Most playbooks take more than default 90s
    $args{sap_sid} //= get_required_var('SAP_SID');
    $args{verbosity_level} //= get_var('SDAF_ANSIBLE_VERBOSITY_LEVEL');

    croak 'Missing mandatory argument "playbook_filename".' unless $args{playbook_filename};
    croak 'Missing mandatory argument "sdaf_config_root_dir".' unless $args{sdaf_config_root_dir};

    my $playbook_options = join(' ',
        sdaf_ansible_verbosity_level($args{verbosity_level}),    # verbosity controlled by OpenQA parameter
        "--inventory-file=\"$args{sap_sid}_hosts.yaml\"",
        "--private-key=$args{sdaf_config_root_dir}/sshkey",
        "--extra-vars='_workspace_directory=$args{sdaf_config_root_dir}'",
        '--extra-vars="@sap-parameters.yaml"',    # File is generated by SDAF, check official docs (SYNOPSIS) for more
        '--ssh-common-args="-o StrictHostKeyChecking=no -o ServerAliveInterval=60 -o ServerAliveCountMax=120"'
    );

    $output_log_file = log_dir() . "/$args{playbook_filename}" =~ s/.yaml|.yml/.txt/r;
    my $playbook_file = join('/', deployment_dir(), 'sap-automation', 'deploy', 'ansible', $args{playbook_filename});
    my $playbook_cmd = join(' ', 'ansible-playbook', $playbook_options, $playbook_file);

    record_info('Playbook run', "Executing playbook: $playbook_file\nExecuted command:\n$playbook_cmd");
    assert_script_run("cd $args{sdaf_config_root_dir}");
    my $rc = script_run(log_command_output(command => $playbook_cmd, log_file => $output_log_file),
        timeout => $args{timeout}, output => "Executing playbook: $args{playbook_filename}");
    upload_logs($output_log_file);
    die "Execution of playbook failed with RC: $rc" if $rc;
    record_info('Playbook OK', "Playbook execution finished: $playbook_file");
}

=head2 sdaf_ansible_verbosity_level

    sdaf_ansible_verbosity_level($verbosity_level);

Returns string that is to be used as verbosity parameter B<-v>  for 'ansible-playbook' command.
This is controlled by positional argument B<$verbosity_level>.
Values can specify verbosity level using integer up to 6 (max supported by ansible)
or just set to anything equal to B<'true'> which will default to B<-vvvv>. Value B<-vvvv> should be enough to debug network
connection problems according to ansible documentation:
L<https://docs.ansible.com/ansible/latest/cli/ansible-playbook.html#cmdoption-ansible-playbook-v>

=over

=item * B<$verbosity_level>: Change default verbosity value by either anything equal to 'true' or int between 1-6. Default: false

=back
=cut

sub sdaf_ansible_verbosity_level {
    my ($verbosity_level) = @_;
    return '' unless $verbosity_level;
    return '-' . 'v' x $verbosity_level if looks_like_number($verbosity_level) and $verbosity_level <= 6;
    return '-vvvv';    # Default set to "-vvvv"
}

=head2 get_sdaf_instance_id

    get_sdaf_instance_id(pattern=>['SCS', 'ERS', 'PAS']);

Get instance id number from SAP_SYSTEM.tfvar.

=over

=item * B<pattern>: SDAF SAP Central Services pattern

=back
=cut

sub get_sdaf_instance_id {
    my (%args) = @_;
    my $pattern = lc($args{pattern});
    my $instance_id = '00';

    my $tfvar_file = get_os_variable('sap_system_parameter_file');
    $instance_id = script_output("grep ^${pattern}_instance_number $tfvar_file | cut -d '=' -f2 | grep -o '[0-9]\\+'");
    record_info("$args{pattern} ID: $instance_id");
    return $instance_id;
}

=head2 ansible_show_status

    ansible_show_status(scenarios=>['db_install', 'db_ha'] sdaf_config_root_dir=>'/some/path' [, sap_sid=>'CAT']);

Display simple command outputs from all DB hosts using B<ansible> command.

=over

=item * B<sdaf_config_root_dir>: SDAF Config directory containing SUT ssh keys

=item * B<sap_sid>: SAP system ID. Default 'SAP_SID'

=item * B<scenarios>: ARRAYREF with list of installed components

=back
=cut

sub ansible_show_status {
    my (%args) = @_;
    foreach ('sdaf_config_root_dir', 'scenarios') {
        croak "Missing mandatory argument '$_'." unless $args{$_};
    }

    $args{sap_sid} //= get_required_var('SAP_SID');
    my %common_args = (sdaf_config_root_dir => $args{sdaf_config_root_dir}, sap_sid => $args{sap_sid});
    my $host_group = 'all';
    my @reports;

    # Show OS info
    push @reports, {title => 'OS info', text => ansible_execute_command(command => 'cat /etc/os-release', host_group => 'all', %common_args)};

    # Show Hana database related information
    if (grep(/db_install/, @{$args{scenarios}})) {
        $host_group = "$args{sap_sid}_DB";

        push @reports, {title => 'DB processes', text => ansible_execute_command(command => 'ps -ef | grep hdb', host_group => $host_group, %common_args)};
        push @reports, {title => 'HDB info', text => ansible_execute_command(command => 'sudo -u hdbadm /hana/shared/HDB/HDB00/HDB info', host_group => $host_group, %common_args)};
    }

    # Show cluster related information
    if (grep(/ha/, @{$args{scenarios}})) {
        $host_group = "$args{sap_sid}_DB";

        push @reports, {title => 'DB cluster', text => ansible_execute_command(command => 'sudo crm status full', host_group => $host_group, %common_args)};
        push @reports, {title => 'HanaSR status', text => ansible_execute_command(command => 'sudo SAPHanaSR-showAttr', host_group => $host_group, %common_args)};
    }

    # Show ENSA2 related information
    my $sapcontrol_path = "/sapmnt/$args{sap_sid}/exe/uc/linuxx86_64";
    my $sapcontrol_env = "sudo env LD_LIBRARY_PATH=$sapcontrol_path:\$LD_LIBRARY_PATH";
    my $sapcontrol_cmd = "$sapcontrol_env $sapcontrol_path/sapcontrol";
    my $instance_id = get_sdaf_instance_id(pattern => 'SCS');
    my $function = '';
    if (grep(/ensa/, @{$args{scenarios}})) {
        # Get instance ID
        $instance_id = get_sdaf_instance_id(pattern => 'SCS');
        $host_group = "$args{sap_sid}_SCS";

        push @reports, {title => 'ENSA2 cluster', text => ansible_execute_command(command => 'sudo crm status full', host_group => $host_group, %common_args)};
        $function = 'HACheckConfig';
        push @reports, {title => "ENSA2 $function", text => ansible_execute_command(command => "$sapcontrol_cmd -nr $instance_id -function $function", host_group => $host_group, %common_args)};
        $function = 'HACheckFailoverConfig';
        push @reports, {title => "ENSA2 $function", text => ansible_execute_command(command => "$sapcontrol_cmd -nr $instance_id -function $function", host_group => $host_group, %common_args)};
    }

    # Show NW processes for each type of instance
    if (grep(/nw/, @{$args{scenarios}})) {
        foreach my $pattern (qw(PAS ERS SCS)) {
            my $pattern_lc = lc($pattern);
            # Get instance ID
            $instance_id = get_sdaf_instance_id(pattern => $pattern);
            $host_group = "$args{sap_sid}_$pattern";

            push @reports, {title => "NW $pattern processes", text => ansible_execute_command(command => 'ps -ef | grep sap', host_group => $host_group, %common_args)};
            # Add 'proceed_on_failure => 1' for 'GetProcessList' as it returns 'rc=3' (RC 3 = all processes GREEN)
            $function = 'GetProcessList';
            push @reports, {title => "NW $pattern $function", text => ansible_execute_command(command => "$sapcontrol_cmd -nr $instance_id -function $function", host_group => $host_group, %common_args, proceed_on_failure => 1)};
            $function = 'GetSystemInstanceList';
            push @reports, {title => "NW $pattern $function", text => ansible_execute_command(command => "$sapcontrol_cmd -nr $instance_id -function $function", host_group => $host_group, %common_args)};
        }
    }

    foreach (@reports) {
        record_info($_->{title}, $_->{text});
    }
}

=head2 ansible_execute_command

    ansible_execute_command(
        command=>'rm -Rf /', host_group=>'QES_SCS', sdaf_config_root_dir=>'/some/path' , sap_sid=>'CAT');

Execute command on host group using ansible. Returns execution output.

=over

=item * B<sdaf_config_root_dir>: SDAF Config directory containing SUT ssh keys

=item * B<sap_sid>: SAP system ID. Default 'SAP_SID'

=item * B<host_group>: Host group name from inventory file

=item * B<command>: Command to be executed

=item * B<verbose>: verbose ansible output

=item * B<proceed_on_failure>: proceed on failure setting

=back
=cut

sub ansible_execute_command {
    my (%args) = @_;
    croak 'Missing mandatory argument "sdaf_config_root_dir".' unless $args{sdaf_config_root_dir};

    my @cmd = ('ansible', $args{host_group},
        "--private-key=$args{sdaf_config_root_dir}/sshkey",
        "--inventory=$args{sap_sid}_hosts.yaml",
        $args{verbose} ? '-vvv' : '',
        '--module-name=shell');

    return script_output(join(' ', @cmd, "--args=\"$args{command}\""), proceed_on_failure => $args{proceed_on_failure});
}

=head2 playbook_settings

    playbook_settings(components=>['db_install', 'db_ha']);

Display simple command outputs from all DB hosts using B<ansible> command.

=over

=item * B<components>: B<ARRAYREF> of components that should be installed

=back
=cut

sub playbook_settings {
    my (%args) = @_;
    # General playbooks that must be run in all scenarios
    my @playbooks = (
        # Fetches SSH key from Workload zone keyvault for accesssing SUTs
        {playbook_filename => 'pb_get-sshkey.yaml', timeout => 90},
        # Validate parameters
        {playbook_filename => 'playbook_00_validate_parameters.yaml', timeout => 120},
        # Base operating system configuration
        {playbook_filename => 'playbook_01_os_base_config.yaml'});

    # DB installation pulls in SAP specific configuration
    if (grep /db_install/, @{$args{components}}) {
        # SAP-specific operating system configuration
        push @playbooks, {playbook_filename => 'playbook_02_os_sap_specific_config.yaml'};
        # SAP Bill of Materials processing - this also mounts install media storage
        push @playbooks, {playbook_filename => 'playbook_03_bom_processing.yaml', timeout => 7200};
        # SAP HANA database installation
        push @playbooks, {playbook_filename => 'playbook_04_00_00_db_install.yaml', timeout => 1800};
    }

    # playbooks required for all nw* scenarios
    if (grep /nw/, @{$args{components}}) {
        # SAP ASCS installation, including ENSA if specified in tfvars
        push @playbooks, {playbook_filename => 'playbook_05_00_00_sap_scs_install.yaml', timeout => 7200};
        # Execute database import
        push @playbooks, {playbook_filename => 'playbook_05_01_sap_dbload.yaml', timeout => 7200};
    }

    # Run HA related playbooks at the end as it can mix up node order ###
    if (grep /db_ha/, @{$args{components}}) {
        # SAP HANA high-availability configuration
        push @playbooks, {playbook_filename => 'playbook_04_00_01_db_ha.yaml', timeout => 1800};
    }

    # playbooks required for all nw* scenarios
    if (grep /nw/, @{$args{components}}) {
        # SAP primary application server installation
        push @playbooks, {playbook_filename => 'playbook_05_02_sap_pas_install.yaml', timeout => 7200};
        # SAP additional application server installation
        push @playbooks, {playbook_filename => 'playbook_05_03_sap_app_install.yaml', timeout => 3600};
    }

    if (grep /nw_ensa/, @{$args{components}}) {
        # Configure ENSA cluster
        push @playbooks, {playbook_filename => 'playbook_06_00_acss_registration.yaml', timeout => 1800};
    }

    return (\@playbooks);
}

=head2 sdaf_register_byos

    sdaf_register_byos(sdaf_config_root_dir=>'/stairway/to_heaven', scc_reg_code=>'CODE-XYZ', sap_sid='PRD');

Performs SCC registration on BYOS image using B<registercloudguest> method.

=over

=item * B<sdaf_config_root_dir>: SDAF root configuration directory

=item * B<scc_reg_code>: SCC registration code

=item * B<sap_sid>: SAP system ID

=back
=cut

sub sdaf_register_byos {
    my (%args) = @_;
    my @mandatory_args = qw(sdaf_config_root_dir scc_reg_code sap_sid);

    for my $arg (@mandatory_args) {
        croak "Missing mandatory argument \$args($arg)", unless $args{$arg};
    }

    record_info('Register SUTs');
    assert_script_run("cd $args{sdaf_config_root_dir}");
    ansible_execute_command(
        command => "sudo registercloudguest -r $args{scc_reg_code}",
        host_group => "$args{sap_sid}_DB",
        sdaf_config_root_dir => $args{sdaf_config_root_dir},
        sap_sid => $args{sap_sid},
        verbose => 1
    );
}

=head2 sdaf_deployment_reused

    sdaf_deployment_reused(quiet=>'BeQuiet!');

If an existing deployment is being reused according to openQA setting `SDAF_DEPLOYMENT_ID`, function will display
`record_info` message with details and returns deployment ID. Otherwise returns nothing/false.
Argument B<quiet> can be used to disable `record_info` message.

=over

=item * B<quiet>: Hide 'record_info' message. Default: undef

=back
=cut

sub sdaf_deployment_reused {
    my (%args) = @_;
    my $deployment_id = get_var('SDAF_DEPLOYMENT_ID');
    return unless $deployment_id;

    record_info(
        'Deploy skip', "OpenQA setting 'SDAF_DEPLOYMENT_ID' defined.\nExisting deployment '$deployment_id' will be used.")
      if !$args{quiet};

    return $deployment_id;
}

1;
